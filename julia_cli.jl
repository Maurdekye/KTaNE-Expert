module CLI

export Command, CommandList, repl, yesnoprompt, findcommand, helptext

struct Command
    names::Vector{String}
    arglist::Vector{Union{Type{String},Type{Int}}}
    requiredargs::Int
    helptext::String
    action
end

mutable struct CommandList
    commands::Vector{Command}
    shouldexit::Bool
end
CommandList(commands) = CommandList(commands, false)

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

clean(text) = lowercase(strip(text))

function yesnoprompt(prompt::String)::Bool
    print("$prompt (y/n) ")
    response = readline()
    return clean(response) == "y"
end

function parsevalidate(command::Command, input::String)::Vector{Union{String,Int}}
    inputlist = split(input)
    finallist = Vector{Union{String,Int}}()
    if length(inputlist) < command.requiredargs
        throw(CommandException("Not enough arguments provided; need at least $(command.requiredargs), you gave $(length(inputlist))"))
    elseif length(inputlist) > length(command.arglist)
        throw(CommandException("Too many arguments! need $(length(command.arglist)), but you gave $(length(inputlist))"))
    else
        for (i, (arg, type)) in enumerate(zip(inputlist, command.arglist))
            if type == String
                push!(finallist, string(arg))
            elseif type == Int
                try
                    parsedint = parse(Int, arg)
                    push!(finallist, parsedint)
                catch ArgumentError
                    throw(CommandException("Argument $i should be an integer, but '$(arg)' isn't an integer far as I can tell."))
                end
            end # assuming the only two types of inputs needed are String and Int
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

function splitcmd(input::String)::Tuple{String,String}
    inputsplit = split(input; limit=2)
    length(inputsplit) == 2 && return (inputsplit[1], inputsplit[2])
    length(inputsplit) == 1 && return (inputsplit[1], "")
end

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
                println("Command '$label' not found. Type `commands` for a list of commands.")
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
            cmd.action(arglist...)
        end
    catch e
        isa(e, InterruptException) || rethrow(e)
    end
end

end