include("julia_cli.jl"); using .
CLI

mutable struct Bomb
    memodict::Dict{String,Any}
end
Bomb() = Bomb(Dict())

abstract type AbstractQuestion end

struct StringQuestion <: AbstractQuestion
    question::String
end

struct BooleanQuestion <: AbstractQuestion
    question::String
end

struct IntegerQuestion <: AbstractQuestion
    question::String
end

function Base.getindex(bomb::Bomb, question::AbstractQuestion)
    value = undef
    if isa(question, StringQuestion)
        print("$(question.question)? ")
        value = clean(readline())
    elseif isa(question, BooleanQuestion)
        value = yesnoprompt("$(question.question)?"; force=true)
    elseif isa(question, IntegerQuestion)
        while true
            print("$(question.question)? ")
            try
                value = parse(Int, strip(readline()))
                break
            catch e
                if isa(e, ArgumentError)
                    println("Please give an integer.")
                else
                    rethrow(e)
                end
            end
        end
    end
    question ∉ bomb.memodict && (bomb.memodict[question] = value)
    bomb.memodict[question]
end

function Base.setindex!(bomb::Bomb, question::String, value)
    bomb.memodict[question] = value
end

Base.in(question::String, bomb::Bomb) = question in bomb.memodict

version = "1.0.0"

introtext = """

Keep Talking and Nobody Explodes
Expert Bot 9000 v$version

"""

bomb = Bomb()
qcodes = Dict(
    "serial_vowel" => BooleanQuestion("Serial number contains a vowel"),
    "serial_odd" => BooleanQuestion("Serial number ends with an odd digit"),
    "serial" => StringQuestion("Serial number"),
    "batt_count" => IntegerQuestion("Number of batteries")
)

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
    ),
    Command(
        ["wires"],
        [String],
        1,
        """Solves the basic wires module.
        Usage: wires <sequence>

        Provide a sequence of characters corresponding to the color and number of wires in the module, according to this pattern:

        R - Red
        G - Green
        B - Blue
        Y - Yellow
        W - White
        K - Black

        Examples:

        One red wire, two yellow wires: `wires RYY`
        Two black wires, one yellow, one red, and one blue: `wires KKYRB`""",
        function(sequence)
            # check validity of passed sequence
            if length(sequence) ∉ 3:6
                println("Wires come in bunches of 3-6, you gave a sequence of $(length(sequences)) wires.")
                return
            end

            if any(l ∉ ['r', 'g', 'b', 'y', 'w', 'k'] for l in sequence)
                println("Wire sequences can only consist of the letters R, G, B, Y, W, and K.")
                return
            end

            # solve module
            tocut = undef
            if length(sequence) == 3
                if 'r' ∉ sequence
                    tocut = 2
                elseif sequence[end] == 'w'
                    tocut = 3
                elseif count(w -> w == 'b', sequence) > 1
                    tocut = findlast(map(l -> l == 'b', sequence))
                else
                    tocut = 3
                end
            elseif length(sequence) == 4
                if count(w -> w == 'r', sequence) > 1 && bomb[qcodes["serial_odd"]]
                    tocut = 4
                elseif sequence[end] == 'y' && all(w -> w != r, sequence)
                    tocut = 1
                elseif count(w -> w == 'b', sequence) == 1
                    tocut = 1
                elseif count(w -> w == 'y', sequence) > 1
                    tocut = 4
                else
                    tocut = 2
                end
            elseif 
        end
    )
])

function main()
    println(introtext)
    repl(ktane_commandlist)
end

isinteractive() || main()