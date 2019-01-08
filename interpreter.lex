%option noyywrap 

%{
#include "structs_interpreter.hpp"
#include <iostream>

#include "y.tab.h"

int yyparse();

//---- Global variables
extern unsigned int line;
extern unsigned int column;
extern bool debug;

//---- Functions
inline void assign_yylval_str(char* text);
%}

%x COMMENT TEXT_

%%
"WHILE"|"while" { column += 5; return WHILE; }
"PRINT"|"print" { column += 5; return PRINT; }
"IF"|"if" { column += 2; return IF; }

["] { BEGIN(TEXT_); }
<TEXT_>[ -~]*["] {
	assign_yylval_str(yytext);
	yylval.str->pop_back();
	BEGIN(INITIAL);
	return TEXT;
}
<TEXT_>. { return UNK; }

[a-zA-Z][a-zA-Z0-9_]* { //VARIABLE
	assign_yylval_str(yytext);
	return VARNAME;
}

"+"|"-"|"*"|"/"|"^" { //OPERATOR
	column++;
	return yytext[0];
}

[0-9]+([.][0-9]+)? { //NUMBER
	column += std::string(yytext).length();
	yylval.fVal = atof(yytext);
	return NUMBER;
}

"=="|"!="|">"|">="|"<"|"<=" { //COMPARATOR
	column += std::string(yytext).length();
	assign_yylval_str(yytext);
	return COMPARATOR;
}
[=;(){},] { column++; return yytext[0]; }

"//".*$   { /*komentarz jedno-wierszowy*/ }

"/*" { column += 2; BEGIN(COMMENT); }
<COMMENT>(\n|\r|\r\n) { line++; }
<COMMENT>"*/" { column += 2; BEGIN(INITIAL); }
<COMMENT>[\t] { column += 5; }
<COMMENT>. { column++; }

[\n]|[\r]|[\r\n] { line++; return NEWLINE; }
[ ] { column++; }
[\t] { column += 5; }

. { return UNK; }
%%

int display_manual(){
	std::cout << "\nRuns interpreter for simple custom programming language.\n\n";
	std::cout << "INTERPRETER -n\n";	
	std::cout << "INTERPRETER -d\n\n";	
	std::cout << "-n	Runs application in normal mode.\n";	
	std::cout << "-d	Runs application in debug mode.\n";	
	return 1;
}

int main(int argc, char* argv[]){
	if (argc == 2) { 
		if(std::string(argv[1]) == "-n") { debug = false; }
		else if (std::string(argv[1]) == "-d") { debug = true; }
		else { return display_manual(); }
	}
	else  { return display_manual(); }
	return yyparse();
}

int yyerror(const char* str) {
	std::cerr << line << ':' << column << ": error: ";
	std::cerr << str << "!\n";
	return 1;
}

//---- Functions

/*
 * Assigns text content to yylval str field.
 *
 * @param text Text to assign to yylval str.
 * @return void.
*/
void assign_yylval_str(char* text) {
	yylval.str = new std::string(text);
	column += yylval.str->length();
}
