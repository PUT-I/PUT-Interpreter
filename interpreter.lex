%option noyywrap 

%{
#include "structs_interpreter.hpp"
#include <string>
#include <iostream>

#include "y.tab.h"

int yyparse();

//---- Global variables
extern unsigned int line;
extern unsigned int column;

//---- Functions
inline void assign_yylval_str(char* text);
%}

%x COMMENT

%%
"WHILE"|"while" { column += 5; return WHILE; }
"PRINT"|"print" { column += 5; return PRINT; }
"IF"|"if" { column += 2; return IF; }

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

int main(void ){ yyparse(); return 1; }

int yyerror(const char* str) {
	std::cerr << line << ':' << column << ": error: ";
	std::cerr << str << "!\n";
	return 1;
}

//---- Functions

/*
 * Assigns text content to yylval strName field.
 *
 * @param text Text to assign to yylval strName.
 * @return void.
*/
void assign_yylval_str(char* text) {
	yylval.strName = new std::string(text);
	column += yylval.strName->length();
}
