include("julia_cli.jl"); using .
CLI

mutable struct Bomb
    memodict::Dict{String,Union{String,Int}}
end
Bomb() = Bomb(Dict())

function Base.getindex(bomb::Bomb, question::String)::String
    question ∉ bomb.memodict && (bomb.memodict[question] = readline(question))
    bomb.memodict[question]
end

function Base.setindex!(bomb::Bomb, question::String, value::Union{String,Int})
    bomb.memodict[question] = value
end

Base.in(question::String, bomb::Bomb) = question in bomb.memodict

version = "1.0.0"

introtext = """

Keep Talking and Nobody Explodes
Expert Bot 9000 v$version

"""

bomb = Bomb()

ktane_commandlist = CommandList([
    Command(
        ["help", "h", "?"],
        [String],
        0,
        """Display help information.
        Usage: help [command]""",
        function(cmd = nothing)
            if cmd === nothing
                println("""Welcome to KTaNE Expert Bot 9000 v$version

                Type `commands` for a list of commands. To begin defusal, simply type in the command corresponding to the name of the module that you're currently defusing. The program will ask you for relevant information it needs in order to know how to finish the defusal, before giving you the answer. 
                    
                The expert will remember elements of the bomb that you tell it about, such as the number of batteries in the bomb, and the serial code, so you will only need to type those on once, if needed.""")
            else
                command = findcommand(cmd, ktane_commandlist)
                if command === nothing
                    println("Command '$cmd' not found. Type `commands` for a list of commands.")
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
            for command in ktane_commandlist.commands
                println(command.names[1]) # assume all commands have at least one name
            end
        end
    ),
    Command(
        ["reset"],
        [],
        0,
        """Reset the program's memory about the bomb, including information like the bomb's serial number & number of batteries.
        Usage: reset""",
        function()
            if yesnoprompt("Are you sure you want to reset?")
                bomb = Bomb()
                println("Memory reset.")
            else
                println("Reset aborted.")
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
                ktane_commandlist.shouldexit = true 
            end
        end
    )
])

function main()
    println(introtext)
    repl(ktane_commandlist)
end

isinteractive() || main()