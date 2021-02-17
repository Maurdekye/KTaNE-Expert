module CLI
using Base.Iterators

export Command, RawCommand, CommandList, repl, yesnoprompt, textprompt, findcommand, 
helptext, clean, dictmap, word_similarity, searchcommands, similarcommands

struct Command
    names::Vector{String}
    arglist::Vector{Union{Type{String},Type{Int}}}
    requiredargs::Int
    helptext::String
    action
    takesraw::Bool
end
Command(n, ar, r, h, ac) = Command(n, ar, r, h, ac, false)
RawCommand(n, ar, r, h, ac) = Command(n, ar, r, h, ac, true)

mutable struct CommandList
    commands::Vector{Command}
    shouldexit::Bool
end
CommandList(commands) = CommandList(commands, false)
function CommandList(help_text::String, commands::Vector{Command})
    command_list = CommandList([[
        Command(
            ["help", "h", "?"],
            [String],
            0,
            """Display help information.
            Usage: help [command]""",
            function(cmd = nothing)
                if cmd === nothing
                    println(help_text)
                else
                    command = findcommand(cmd, command_list)
                    if command === nothing
                        similar = similarcommands(cmd, command_list)
                        if similar === nothing
                            println("Command '$cmd' not found. Type `commands` for a list of commands.")
                        else
                            println("Command '$cmd' not found. Did you mean $similar?")
                        end
                    else
                        println(helptext(command))
                    end
                end
            end
        ),
        Command(
            ["commands", "c"],
            [],
            0,
            """Display the list of commands.
            Usage: commands""",
            function()
                println("Displaying a list of commands:")
                for command in command_list.commands
                    println(command.names[1]) # assume all commands have at least one name
                end
            end
        ),
        Command(
            ["exit", "quit", "stop", "leave"],
            [],
            0,
            """Exit the program.
            Usage: exit""",
            function()
                if yesnoprompt("Are you sure you want to quit?")
                    println("Goodbye.")
                    command_list.shouldexit = true 
                end
            end
        ),
    ]; commands])
end

struct CommandException <: Exception
    msg::String
end

function helptext(cmd::Command)::String
    aliaslist = join(cmd.names, ", ")
    """
    $aliaslist
    --------------------------------------------------
    $(cmd.helptext)"""
end

dictmap(f, list) = Dict(map(v -> v => f(v), list))

clean(text) = lowercase(strip(text))

function yesnoprompt(prompt::String; force::Bool=false)::Bool
    while true
        print("$prompt (y/n) ")
        response = clean(readline())
        if response in ["y", "yes"]
            return true
        elseif response in ["n", "no"] || !force
            return false
        end
    end
end

function textprompt(prompt::String; choices::Union{Vector{String},Nothing}=nothing)
    while true
        print("$prompt ")
        response = clean(readline())
        if isempty(response) || (choices !== nothing && response ∉ choices)
            continue
        end
        return response
    end
end

function parsevalidate(command::Command, input::String)::Vector{Union{String,Int}}
    inputlist = split(input)
    finallist = Vector{Union{String,Int}}()
    if length(inputlist) < command.requiredargs
        throw(CommandException("Not enough arguments provided; need at least $(command.requiredargs), you gave $(length(inputlist))"))
    elseif length(inputlist) > length(command.arglist) && !command.takesraw
        throw(CommandException("Too many arguments! need $(length(command.arglist)), but you gave $(length(inputlist))"))
    else
        for (i, (arg, type)) in enumerate(zip(inputlist, command.arglist))
            if type == String # assuming the only two types of inputs needed are String and Int
                push!(finallist, string(arg))
            elseif type == Int
                try
                    parsedint = parse(Int, arg)
                    push!(finallist, parsedint)
                catch ArgumentError
                    throw(CommandException("Argument $i should be an integer, but '$arg' isn't an integer far as I can tell."))
                end
            end
        end
    end
    finallist
end

function findcommand(name::String, list::CommandList)::Union{Command,Nothing}
    cleancmd = clean(name)
    for command in list.commands
        if cleancmd in command.names
            return command
        end
    end 
    nothing
end

function searchcommands(search::String, commandlist::CommandList; leniency::Int=3)::Vector{Tuple{Command,Int,Dict{String,Int}}}
    list = Vector{Tuple{Command,Int,Dict{String,Int}}}()
    for command in commandlist.commands
        names = filter(p -> p.second ≤ leniency, dictmap(word_similarity(search), command.names))
        !isempty(names) && push!(list, (command, max(values(names)...), names))
    end
    sort(list, by=(e -> e[2]))
end

function similarcommands(search::String, list::CommandList; leniency::Int=3)
    results = searchcommands(search, list; leniency=leniency)
    names = map(p -> p.first, sort(collect(flatten(map(r -> collect(r[3]), results))), by=(p -> p.second)))
    if isempty(names)
        nothing
    elseif length(names) == 1
        names[1]
    else
        "$(join(names[1:end-1], ", ")), or $(names[end])"
    end
end

function splitcmd(input::String)::Tuple{String,String}
    inputsplit = split(input; limit=2)
    length(inputsplit) == 2 && return (inputsplit[1], inputsplit[2])
    length(inputsplit) == 1 && return (inputsplit[1], "")
end

function word_similarity(word1::String, word2::String)::Int # optimized wagner-fischer levenshtein distance algorithm
    "" in [word1, word2] && return max(length.([word1, word2])...)

    previous = collect(0:length(word2))
    current = undef
  
    for y in 2:length(word1)+1
      current = fill(0, length(word2)+1)
      current[1] = y-1
      for x in 2:length(word2)+1
        if word1[y-1] == word2[x-1]
          current[x] = previous[x-1]
        else
          current[x] = min(current[x-1], previous[x], previous[x-1]) + 1
        end
      end
      previous .= current
    end
  
    current[end]
end

word_similarity(word::String) = word2 -> word_similarity(word, word2)

function repl(commands::CommandList)
    try
        while !commands.shouldexit
            # get input
            print("> ")
            userin = readline()
            isempty(strip(userin)) && continue

            # parse & validate input
            label, args = splitcmd(userin)
            cmd = findcommand(label, commands)
            if cmd === nothing
                similar = similarcommands(label, commands)
                if similar === nothing
                    println("Command '$label' not found. Type `commands` for a list of commands.")
                else
                    println("Command '$label' not found. Did you mean $similar?")
                end
                continue
            end
            arglist = undef
            try
                arglist = parsevalidate(cmd, args)
            catch e
                if isa(e, CommandException)
                    println(e.msg)
                    continue
                else
                    rethrow(e)
                end
            end

            # execute command
            if cmd.takesraw
                cmd.action(arglist...; rawargs = strip(args))
            else
                cmd.action(arglist...)
            end
        end
    catch e
        isa(e, InterruptException) || rethrow(e)
    end
end

end