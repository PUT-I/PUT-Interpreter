# Interpreter_Bison_Flex_CPP
Interpreter written in Bison, Flex and C++ for simple custom programming language.

## Language Syntax
### Instructions
  - assignment - `variable_name = equation`
  - Print - `PRINT(equation)`
  - IF - `IF(equation comparator equation) instruction`
  - IF - `IF(equation comparator equation) { instructions }`
  - WHILE - `WHILE(variable, assignment) instruction`
  - WHILE - `WHILE(variable, assignment) { instructions }`

### Symbols Explanation
  - `equation`:
    - single number,
    - single variable,
    - `+-*/` - addition, subtraction, multiplication and division of variables/numbers,
    - `^` - variable/number to the power of variable/number.
  - `comparator` - one of these words: `==`, `!=`, `>` , `>=`, `<`, `<=`.
  - `instruction` - single instruction.
  - `instructions` - multiple instructions.

### WHILE Explanation
  - first argument - control variable for loop. Breaks the loop upon reaching the value of zero.
  - second argument - assignment executed on first argument.

## Mode Flags
This program uses flags to run in normal mode or debug mode.
Possible run scenarios:<br/>
`INTERPRETER -n`<br/>
`INTERPRETER -d`<br/>
`INTERPRETER -flag < program.txt`

`-n` - runs program in normal mode.<br/>
`-d` - runs program in debug mode.<br/>
`-flag` - any of above flags (used only for example).

## Capabilities
  - debug mode (enabled with flag),
  - real numbers operations,
  - order of operations (eg. multiplication before addition),
  - negative numbers and negated variables,
  - nested instructions (IFs in WHILEs and conversely),
  - single-line and multi-line comments (C/C++ style)
  - error detection (undeclared variable, missing semi-colon, wrong WHILE second argument),
  - line and column tracking (used in error detection).
  
## Example Code
```
var_1 = 3^5;
var_2 = -var_1 + 3 + 120 + 4*5/3;

//This is a commnet (interpreter ignores it)
/*
	This is also ignored
*/

a = 10.5^3;
b = 3 * 10^2/2 + 18/2*3 - 1;

IF ( a >= 10 ) { 
	IF( a < 10000 ){
		print( b );
	};
	print( a );
};
it = -10;
check = 1;

WHILE ( it, it=it+1 ) { 
	IF( check < 128 ) {
		check = check * 2;
		it2 = 2;
		WHILE (it2, it2 = it2 - 1){ 
			PRINT(check);
			IF( it2 == 1 ){
				check = check + 1;
				PRINT(it2);
			};
		};
		IF( it2 == 0 ){
			it2 = it2 + 3*check;
			PRINT(it2);
		};
	};
};

print(0);
print(check);
```
*code written in language defined for the interpreter

## Requirements
To compile this program you need:
  - C++ compiler
  - Flex binaries
  - Bison binaries (may require additional binaries)
  
### Software used for this project
  - [MinGW - Minimalist GNU for Windows](https://sourceforge.net/projects/mingw/)
  - [Flex for Windows](http://gnuwin32.sourceforge.net/packages/flex.htm)
  - [Bison for Windows](http://gnuwin32.sourceforge.net/packages/bison.htm)
  - [Visual Studio Code](https://code.visualstudio.com/) with [Lex Flex Yacc Bison plugin](https://marketplace.visualstudio.com/items?itemName=faustinoaq.lex-flex-yacc-bison)
  
### Console commands (used by me on Windows)
  1. bison.exe -dy interpreter.y
  2. flex.exe interpreter.lex
  3. g++.exe y.tab.c lex.yy.c -o "your_exe_name.exe"


## Thanks
  - [SuddenlyPineapple](https://github.com/SuddenlyPineapple) gave the idea for using enums in switch in `execute_instruction()` function.
