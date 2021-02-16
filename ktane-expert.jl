include("julia_cli.jl"); using .CLI
using Base.Iterators

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

Base.convert(::Type{String}, q::AbstractQuestion) = q.question

mutable struct Bomb
    memodict::Dict{AbstractQuestion,Any}
end
Bomb() = Bomb(Dict())

function Base.getindex(bomb::Bomb, question::AbstractQuestion)
    if question ∉ keys(bomb.memodict)
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
        bomb.memodict[question] = value
    end
    bomb.memodict[question]
end

function Base.setindex!(bomb::Bomb, value, question::AbstractQuestion)
    bomb.memodict[question] = value
end

Base.in(question::String, bomb::Bomb) = question in bomb.memodict

Base.count(c::Char, s::String) = count(isequal(c), s)

version = "1.0.0"

introtext = """Keep Talking and Nobody Explodes
Expert Bot 9000 v$version
"""

bomb = Bomb()
qcodes = Dict(
    "serial_vowel" => BooleanQuestion("Serial number contains a vowel"),
    "serial_odd" => BooleanQuestion("Serial number ends with an odd digit"),
    "serial" => StringQuestion("Serial number"),
    "batt_count" => IntegerQuestion("Number of batteries"),
    "lit_car" => BooleanQuestion("Is there a lit indicator labeled CAR"),
    "lit_frk" => BooleanQuestion("Is there a lit indicator labeled FRK"),
    "strikes" => IntegerQuestion("Number of strikes"),
)
bomb[qcodes["strikes"]] = 0

ktane_commandlist = CommandList("""Welcome to KTaNE Expert Bot 9000 v$version

Type `commands` for a list of commands. To begin defusal, simply type in the command corresponding to the name of the module that you're currently defusing. The program will ask you for relevant information it needs in order to know how to finish the defusal, before giving you the answer. 
    
The expert will remember elements of the bomb that you tell it about, such as the number of batteries in the bomb, and the serial code, so you will only need to type those on once, if needed.

Make sure to record strikes you recieve with the `strike` command; some solutions to modules differ depending on the number of strikes you have!""",
[
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
        ["memory", "memo"],
        [],
        0,
        """Print out information stored in the program's memory about the bomb.
        Usage: memory""",
        function()
            println("Bomb memory:")
            
            for (key, val) in bomb.memodict
                valstr = string(val)
                isa(key, BooleanQuestion) && (valstr = val ? "Yes" : "No")
                println("$key: $val")
            end
        end
    ),
    Command(
        ["serial"],
        [String],
        1,
        """Provide the serial code of the bomb in advance, which may mean that solving future puzzles requires less further input.
        Usage: serial <serial number>""",
        function(serial)
            bomb[qcodes["serial"]] = serial
            bomb[qcodes["serial_vowel"]] = any(v in serial for v in "aeiou")
            bomb[qcodes["serial_odd"]] = serial[end] in "13579"
            println("Set the bomb's serial code to $serial")
        end
    ),
    Command(
        ["strike", "strikes"],
        [Int],
        0,
        """Record a strike, or manually set the number of strikes.
        Usage: strike [number of strikes]
        
        If no argument is given, the number of strikes is incremented by 1. Otherwise, the number is set to the provided argument.""",
        function(strikes=nothing)
            if strikes === nothing
                bomb[qcodes["strikes"]] < 3 && (bomb[qcodes["strikes"]] += 1)
                if bomb[qcodes["strikes"]] == 1
                    println("Now at 1 strike")
                elseif bomb[qcodes["strikes"]] == 2
                    println("Now at 2 strikes")
                else
                    println("BOOM!")
                end
            elseif strikes ∉ 0:3
                println("That doesn't make any sense, you can only have 0, 1, or 2 strikes.")
            else
                bomb[qcodes["strikes"]] = strikes
                println("Set the number of strikes to $strikes")
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
                elseif count('b', sequence) > 1
                    tocut = findlast(map(isequal('b'), sequence))
                else
                    tocut = 3
                end
            elseif length(sequence) == 4
                if count('r', sequence) > 1 && bomb[qcodes["serial_odd"]]
                    tocut = 4
                elseif sequence[end] == 'y' && count('r', sequence) == 0
                    tocut = 1
                elseif count('b', sequence) == 1
                    tocut = 1
                elseif count('y', sequence) > 1
                    tocut = 4
                else
                    tocut = 2
                end
            elseif length(sequence) == 5
                if sequence[end] == 'k' && bomb[qcodes["serial_odd"]]
                    tocut = 4
                elseif count('r', sequence) == 1 && count('y', sequence) > 1
                    tocut = 1
                elseif count('k', sequence) == 0
                    tocut = 2
                else
                    tocut = 1
                end
            elseif length(sequence) == 6
                if count('y', sequence) == 0 && bomb[qcodes["serial_odd"]] 
                    tocut = 3
                elseif count('y', sequence) == 1  count('w', sequence) > 1
                    tocut = 4
                elseif  count('r', sequence) == 0
                    tocut = 6
                else
                    tocut = 4
                end
            end

            # print answer
            wirenames = ["first", "second", "third", "fourth", "this wire is never cut lmao", "sixth"]
            println("Cut the $(wirenames[tocut]) wire.")
        end
    ),
    Command(
        ["button"],
        [String, String],
        2,
        """Solves the button module.
        Usage: button <color> <label>

        Give the color of the button, and the name of the button's label.

        Examples:

        Yellow button with the word 'detonate' written on it: `button yellow detonate`
        White button with the word 'abort': `button white abort`""",
        function(color, label)
            hold = undef
            if color == "blue" && label == "abort"
                hold = true
            elseif label == "detonate" && bomb[qcodes["batt_count"]] > 1
                hold = false
            elseif color == "white" && bomb[qcodes["lit_car"]] 
                hold = true
            elseif bomb[qcodes["batt_count"]] > 2 && bomb[qcodes["lit_frk"]] 
                hold = false
            elseif color == "yellow"
                hold = true
            elseif color == "red" && label == "hold"
                hold = false
            else
                hold = true
            end

            if hold
                println("Press and hold the button, and type in the color of the indicator light that appears;")
                lightcolor = textprompt("|")
                
                releasedigit = 1
                if lightcolor == "blue"
                    releasedigit = 4
                elseif lightcolor == "white"
                    releasedigit = 1
                elseif lightcolor == "yellow"
                    releasedigit = 5
                end

                println("Release the button when the timer has a $releasedigit in any position.")
            else
                println("Immediately press and release the button.")
            end
        end
    ),
    Command(
        ["keypad"],
        [String, String, String, String],
        4,
        """Solves the keypad module.
        Usage: keypad <symbol code 1> <symbol code 2> <symbol code 3> <symbol code 4>

        Use the reference below to determine which symbol codes to type for the respective symbols:

            OL - O with a small line protruding from the bottom
            AT - A with a T inside it
            LM - Lambda symbol with a small stroke through the top
            SN - Swirly reverse N
            TET - Symbol consisting of a sideways T on the left, a downward facing euro symbol below, and an upside down triangle on the top right
            SH - Swirly cursive H with a hook on the bottom right
            CD - C with a dot in the center
            RCD - Reverse C with a dot in the center
            ED - Reverse euro symbol with two dots above it
            Q - Cursive Q
            WS - White Star
            BS - Black Star
            ? - Upside down question mark
            CP - Copyright symbol
            WC - Wavy W with a comma above it, wearing a small hat
            KK - Two K's, mirrored, with adjoined spines
            P3 - Partial 3 with the bottom unfinished and trailed off to the bottom right
            DT - Lowercase delta, looks like a 6 with a flat top
            PR - Reverse paragraph symbol
            BT - Lowercase B with a T serif crossing through it's spine
            FC - Smiley face with it's tongue sticking out
            PSI - Psi symbol, looks like a menorah or canelabra
            S3 - 3 with antennae and a tail that makes it look like a snail
            PZ - Puzzle piece with square edges
            AE - ae
            RN - Reverse uppercase N with a curly bowl above it
            OM - Omega symbol
        
        Examples:
        
        One symbol is an A with a T in it, one is a lambda, one is a swirly H, and one is a reverse C with a dot: `keypad AT LM SH RCD`
        One symbol is a sideways T, E and triangle, one is two mirrored Ks, one is a smiley face, and one is an upside-down question mark: `keypad TET KK FC ?`""",
        function(s1, s2, s3, s4)
            symbol_list = ["OL", "AT", "LM", "RN", "TET", "SH", "CD", "RCD", "ED", "Q", "WS", "BS", "?", "CP", "WC", "KK", "P3", "DT", "PR", "BT", "FC", "PSI", "S3", "PZ", "AE", "RN", "OM"]
            symbol_columns = [
                ["OL", "AT", "LM", "SN", "TET", "SH", "RCD"],
                ["ED", "OL", "RCD", "Q", "WS", "SH", "?"],
                ["CP", "WC", "Q", "KK", "P3", "LM", "WS"],
                ["DT", "PR", "BT", "TET", "KK", "?", "SM"],
                ["PSI", "SM", "BT", "CD", "PR", "S3", "BS"],
                ["DT", "ED", "PZ", "AE", "PSI", "RN", "OM"]
            ]

            given = map(uppercase, [s1, s2, s3, s4])
            badcode = findfirst(code -> code ∉ symbol_list, given)
            if badcode !== nothing
                println("Code $(given[badcode]) isn't a valid code; refer to the helptext for this command to see a list of valid symbol codes.")
                return
            end

            right_col_ind = findfirst(col -> all(symb in col for symb in given), symbol_columns)
            if right_col_ind === nothing
                println("No solution was found... did you type the right codes in?")
                return
            end

            right_col = symbol_columns[right_col_ind]
            correct_order = sort(given, by=(s -> findfirst(isequal(s), right_col)))

            println("The correct order to push the buttons in is $(correct_order[1]), $(correct_order[2]),$(correct_order[3]), and $(correct_order[4]).")
        end
    ),
    Command(
        ["simon", "simonsays"],
        [String],
        1,
        """Solves the simon says module.
        Usage: simon <light sequence>
        
        Provide a sequence of characters corresponding to the color and order of blinking lights that appear.
        
        Use the following reference to determine which letter to type for each color:
            
            R - Red
            B - Blue
            G - Green
            Y - Yellow
            
        Examples:
        
        Flashes green: `simon G`
        Flashes green, yellow, green, blue: `simon GYGB`""",
        function(sequence)
            if bomb[qcodes["strikes"]] ≥ 3
                println("You already exploded!")
                return
            end

            sequence = collect(uppercase(sequence))
            if !all(l in "RBGY" for l in sequence)
                println("Only give color sequences consisting of the letters R, B, G, and Y.")
                return
            end

            header = ['R', 'B', 'G', 'Y']

            translation_table = Dict(
                true => [
                    ['B', 'R', 'Y', 'G'],
                    ['Y', 'G', 'B', 'R'],
                    ['G', 'R', 'Y', 'B']
                ],
                false => [
                    ['B', 'Y', 'G', 'R'],
                    ['R', 'B', 'Y', 'G'],
                    ['Y', 'G', 'B', 'R']
                ]
            )[bomb[qcodes["serial_vowel"]]]

            names = Dict(
                'R' => "Red",
                'B' => "Blue",
                'G' => "Green",
                'Y' => "Yellow"
            )

            indicies = map(s -> findfirst(isequal(s), header), collect(sequence))
            translation = translation_table[bomb[qcodes["strikes"]]+1][indicies]
            solution_response = map(c -> names[c], translation)

            println("Press the buttons in this order: $(join(solution_response, ", ")).")
        end
    ),
    RawCommand(
        ["whosonfirst", "wof"],
        [String],
        0,
        """Solves the Who's on First module.
        Usage: whosonfirst <displayed word>
        
        Examples:
        
        Module has the word 'BLANK' shown: `whosonfirst BLANK`
        Module has no word shown: `whosonfirst `""",
        function(args...; rawargs=nothing)
            word = rawargs === nothing ? "" : uppercase(rawargs)

            display_words = Dict(
                "UR"       => :up_left,
                "FIRST"    => :up_right,
                "OKAY"     => :up_right,
                "C"        => :up_right,
                "YES"      => :middle_left,
                "NOTHING"  => :middle_left,
                "LED"      => :middle_left,
                "THEY ARE" => :middle_left,
                "BLANK"    => :middle_right,
                "READ"     => :middle_right,
                "RED"      => :middle_right,
                "YOU"      => :middle_right,
                "YOUR"     => :middle_right,
                "YOU'RE"   => :middle_right,
                "THEIR"    => :middle_right,
                ""         => :bottom_left,
                "REED"     => :bottom_left,
                "LEED"     => :bottom_left,
                "THEY'RE"  => :bottom_left,
                "DISPLAY"  => :bottom_right,
                "SAYS"     => :bottom_right,
                "NO"       => :bottom_right,
                "LEAD"     => :bottom_right,
                "HOLD ON"  => :bottom_right,
                "YOU ARE"  => :bottom_right,
                "THERE"    => :bottom_right,
                "SEE"      => :bottom_right,
                "CEE"      => :bottom_right,
            )

            location_names = Dict(
                :up_left      => "top left",
                :up_right     => "top right",
                :middle_left  => "middle left",
                :middle_right => "middle right",
                :bottom_left  => "bottom left",
                :bottom_right => "bottom right",
            )

            if word ∉ keys(display_words)
                println("Word not recognized; did you type it in properly?")
                return
            end

            location = display_words[word]

            step_2_words = Dict(
                "READY"   => ["YES", "OKAY", "WHAT", "MIDDLE", "LEFT", "PRESS", "RIGHT", "BLANK", "READY", "NO", "FIRST", "UHHH", "NOTHING", "WAIT"],
                "FIRST"   => ["LEFT", "OKAY", "YES", "MIDDLE", "NO", "RIGHT", "NOTHING", "UHHH", "WAIT", "READY", "BLANK", "WHAT", "PRESS", "FIRST"],
                "NO"      => ["BLANK", "UHHH", "WAIT", "FIRST", "WHAT", "READY", "RIGHT", "YES", "NOTHING", "LEFT", "PRESS", "OKAY", "NO", "MIDDLE"],
                "BLANK"   => ["WAIT", "RIGHT", "OKAY", "MIDDLE", "BLANK", "PRESS", "READY", "NOTHING", "NO", "WHAT", "LEFT", "UHHH", "YES", "FIRST"],
                "NOTHING" => ["UHHH", "RIGHT", "OKAY", "MIDDLE", "YES", "BLANK", "NO", "PRESS", "LEFT", "WHAT", "WAIT", "FIRST", "NOTHING", "READY"],
                "YES"     => ["OKAY", "RIGHT", "UHHH", "MIDDLE", "FIRST", "WHAT", "PRESS", "READY", "NOTHING", "YES", "LEFT", "BLANK", "NO", "WAIT"],
                "WHAT"    => ["UHHH", "WHAT", "LEFT", "NOTHING", "READY", "BLANK", "MIDDLE", "NO", "OKAY", "FIRST", "WAIT", "YES", "PRESS", "RIGHT"],
                "UHHH"    => ["READY", "NOTHING", "LEFT", "WHAT", "OKAY", "YES", "RIGHT", "NO", "PRESS", "BLANK", "UHHH", "MIDDLE", "WAIT", "FIRST"],
                "LEFT"    => ["RIGHT", "LEFT", "FIRST", "NO", "MIDDLE", "YES", "BLANK", "WHAT", "UHHH", "WAIT", "PRESS", "READY", "OKAY", "NOTHING"],
                "RIGHT"   => ["YES", "NOTHING", "READY", "PRESS", "NO", "WAIT", "WHAT", "RIGHT", "MIDDLE", "LEFT", "UHHH", "BLANK", "OKAY", "FIRST"],
                "MIDDLE"  => ["BLANK", "READY", "OKAY", "WHAT", "NOTHING", "PRESS", "NO", "WAIT", "LEFT", "MIDDLE", "RIGHT", "FIRST", "UHHH", "YES"],
                "OKAY"    => ["MIDDLE", "NO", "FIRST", "YES", "UHHH", "NOTHING", "WAIT", "OKAY", "LEFT", "READY", "BLANK", "PRESS", "WHAT", "RIGHT"],
                "WAIT"    => ["UHHH", "NO", "BLANK", "OKAY", "YES", "LEFT", "FIRST", "PRESS", "WHAT", "WAIT", "NOTHING", "READY", "RIGHT", "MIDDLE"],
                "PRESS"   => ["RIGHT", "MIDDLE", "YES", "READY", "PRESS", "OKAY", "NOTHING", "UHHH", "BLANK", "LEFT", "FIRST", "WHAT", "NO", "WAIT"],
                "YOU"     => ["SURE", "YOU ARE", "YOUR", "YOU'RE", "NEXT", "UH HUH", "UR", "HOLD", "WHAT?", "YOU", "UH UH", "LIKE", "DONE", "U"],
                "YOU ARE" => ["YOUR", "NEXT", "LIKE", "UH HUH", "WHAT?", "DONE", "UH UH", "HOLD", "YOU", "U", "YOU'RE", "SURE", "UR", "YOU ARE"],
                "YOUR"    => ["UH UH", "YOU ARE", "UH HUH", "YOUR", "NEXT", "UR", "SURE", "U", "YOU'RE", "YOU", "WHAT?", "HOLD", "LIKE", "DONE"],
                "YOU'RE"  => ["YOU", "YOU'RE", "UR", "NEXT", "UH UH", "YOU ARE", "U", "YOUR", "WHAT?", "UH HUH", "SURE", "DONE", "LIKE", "HOLD"],
                "UR"      => ["DONE", "U", "UR", "UH HUH", "WHAT?", "SURE", "YOUR", "HOLD", "YOU'RE", "LIKE", "NEXT", "UH UH", "YOU ARE", "YOU"],
                "U"       => ["UH HUH", "SURE", "NEXT", "WHAT?", "YOU'RE", "UR", "UH UH", "DONE", "U", "YOU", "LIKE", "HOLD", "YOU ARE", "YOUR"],
                "UH HUH"  => ["UH HUH", "YOUR", "YOU ARE", "YOU", "DONE", "HOLD", "UH UH", "NEXT", "SURE", "LIKE", "YOU'RE", "UR", "U", "WHAT?"],
                "UH UH"   => ["UR", "U", "YOU ARE", "YOU'RE", "NEXT", "UH UH", "DONE", "YOU", "UH HUH", "LIKE", "YOUR", "SURE", "HOLD", "WHAT?"],
                "WHAT?"   => ["YOU", "HOLD", "YOU'RE", "YOUR", "U", "DONE", "UH UH", "LIKE", "YOU ARE", "UH HUH", "UR", "NEXT", "WHAT?", "SURE"],
                "DONE"    => ["SURE", "UH HUH", "NEXT", "WHAT?", "YOUR", "UR", "YOU'RE", "HOLD", "LIKE", "YOU", "U", "YOU ARE", "UH UH", "DONE"],
                "NEXT"    => ["WHAT?", "UH HUH", "UH UH", "YOUR", "HOLD", "SURE", "NEXT", "LIKE", "DONE", "YOU ARE", "UR", "YOU'RE", "U", "YOU"],
                "HOLD"    => ["YOU ARE", "U", "DONE", "UH UH", "YOU", "UR", "SURE", "WHAT?", "YOU'RE", "NEXT", "HOLD", "UH HUH", "YOUR", "LIKE"],
                "SURE"    => ["YOU ARE", "DONE", "LIKE", "YOU'RE", "YOU", "HOLD", "UH HUH", "UR", "SURE", "U", "WHAT?", "NEXT", "YOUR", "UH UH"],
                "LIKE"    => ["YOU'RE", "NEXT", "U", "UR", "HOLD", "DONE", "UH UH", "WHAT?", "UH HUH", "YOU", "LIKE", "SURE", "YOU ARE", "YOUR"],
            )

            button_word = uppercase(textprompt("What is the word on the $(location_names[location]) button?"; choices = lowercase.(keys(step_2_words))))
            
            for step_2_word in cycle(step_2_words[button_word])
                print("Is there a button with the word '$step_2_word' on it? (leave blank for no) ")
                response = clean(readline())
                if !(response in ["", "n", "no"])
                    println("Press that button.")
                    break
                end
            end
        end
    )
])

function main()
    # bomb[qcodes["serial_vowel"]] = false
    # findcommand("simon", ktane_commandlist).action("RGBY")
    println(introtext)
    repl(ktane_commandlist)
end

isinteractive() || main()