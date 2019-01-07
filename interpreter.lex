%option noyywrap

%{
#include "structs_interpreter.hpp"
#include <string>
#include <iostream>

#include "y.tab.h"

int yyparse();

//---- Zmienne globalne
extern unsigned int line;
extern unsigned int column;

//---- Funkcje
inline void assign_yylval_str(char*& text);
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

"=="|">"|">="|"<"|"<=" { //COMPARATOR
	column += std::string(yytext).length();
	assign_yylval_str(yytext);
	return COMPARATOR;
}
[=;(){},] { column++; return yytext[0]; }

"//".*$   { /*komentarz jedno-wierszowy*/ }

"/*" { BEGIN(COMMENT); }
<COMMENT>(.|\n|\r|\r\n)*"*/" { BEGIN(INITIAL); }

[\n]|[\r]|[\r\n] { line++; return NEWLINE; }
[ \t] { column++; }

. { return UNK; }
%%

int main(void ){ yyparse(); return 1; }

int yyerror(const char* str) {
	std::cerr << line << ':' << column << ": error: ";
	std::cerr << str << "!\n";
	return 1;
}

void assign_yylval_str(char*& text) {
	yylval.strName = new std::string(yytext);
	column += yylval.strName->length();
}
