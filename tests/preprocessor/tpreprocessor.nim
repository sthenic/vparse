import streams
import terminal
import strformat

include ../../src/vparsepkg/preprocessor

var
   nof_passed = 0
   nof_failed = 0


# template run_test(title, stimuli: string, reference: untyped) =


#    try:
#       for i in 0..<response.len:
#          if debug:
#             echo pretty(response[i])
#             echo pretty(reference[i])
#          do_assert(response[i] == reference[i], "'" & $response[i] & "'")
#       styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
#                       fgWhite, "Test '",  title, "'")
#       nof_passed += 1
#    except AssertionError:
#       styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
#                       fgWhite, "Test '",  title, "'")
#       nof_failed += 1
#    except IndexError:
#       styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
#                       fgWhite, "Test '",  title, "'", #resetStyle,
#                       " (missing reference data)")
#       nof_failed += 1


var p: Preprocessor
echo preprocess(p, "test_default", [""], new_string_stream("""
Hello
`define THING
Hola
"""))
