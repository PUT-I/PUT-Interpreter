%{
    #include "structs_interpreter.hpp"
	#include <iostream>
    #include <iomanip>

    //---- Function declarations to use in lex file
	int yylex();
	int yyerror(const char*);

    //---- Global variables
    std::map<std::string, double> variables;
    static int dummy = 0;
    unsigned int line = 1;
    unsigned int column = 1;
    bool debug;
 
    //---- Functions
    inline int check_variable_declaration(const std::string& variableName);
    inline void execute_instruction(std::vector<Instruction>& instructions, const int i, int& i_ref);
%}

%union {
    double fVal;
    std::string* strName;
    std::vector<Instruction>* Instructions;
    Equation* equation;
};

/*---- Nonterminals ----*/
%start PROGRAM
%type<equation> EQUATION
%type<Instructions> ASSIGNMENT
%type<Instructions> INSTRUCTIONS
%type<Instructions> INSTRUCTIONS_MULTI
%type<strName> VARIABLE
%type<strName> OPERATOR

/*---- Tokens with type ----*/
%token <fVal> NUMBER
%token <strName> VARNAME
%token <strName> COMPARATOR

/*---- Tokens without type ----*/
%token UNK
%token PRINT
%token IF
%token WHILE
%token NEWLINE

%%

/*---- Rules - S ----*/
PROGRAM : PROGRAM INSTRUCTIONS ';' {
                std::cout << std::setprecision(15);
                if(!$2->empty()) { execute_instruction(*$2, 0, dummy); }
                delete $2;
            }
        | PROGRAM INSTRUCTIONS { return yyerror("expected ';' at the end of instruction"); }
        | PROGRAM INSTRUCTIONS NEWLINE { line--; column--; return yyerror("expected ';' at the end of instruction"); }
        | PROGRAM NEWLINE { column = 1; }
        | /*nic*/
        ;

/*---- Rules - OPERATOR ----*/
OPERATOR : '+' { $$ = new std::string("+"); }
         | '-' { $$ = new std::string("-"); }
         | '*' { $$ = new std::string("*"); }
         | '/' { $$ = new std::string("/"); }
         | '^' { $$ = new std::string("^"); }
         ;

/*---- Rules - INSTRUCTIONS_MULTI ----*/
INSTRUCTIONS_MULTI : INSTRUCTIONS_MULTI INSTRUCTIONS ';' { $$->insert($$->end(), $2->begin(), $2->end()); }
                   | INSTRUCTIONS_MULTI INSTRUCTIONS { line--; column--; return yyerror("expected ';' at the end of instruction"); }
                   | INSTRUCTIONS_MULTI NEWLINE { column = 1; }
                   | /*nic*/{
                       $$ = new std::vector<Instruction>();
                    }
                   ;

/*---- Rules - INSTRUCTIONS ----*/
INSTRUCTIONS : PRINT '(' EQUATION ')' {
                    $$ = new std::vector<Instruction>(1);
                    (*$$)[0].equations.push_back(*$3); delete $3;
                    (*$$)[0].type = PRINT_;
                }
		    | ASSIGNMENT { $$ = $1; }
            | IF '(' EQUATION COMPARATOR EQUATION ')' INSTRUCTIONS {
                    $$ = $7;
                    Instruction temp;
                    temp.equations.push_back(*$3); delete $3;
                    temp.equations.push_back(*$5); delete $5;
                    temp.type = IF_;
                    temp.comparator = *$4; delete $4;
                    $$->insert($$->begin(), temp);
                }
            | IF '(' EQUATION COMPARATOR EQUATION ')' '{' INSTRUCTIONS_MULTI '}' {
                    $$ = $8;
                    Instruction temp;
                    temp.equations.push_back(*$3); delete $3;
                    temp.equations.push_back(*$5); delete $5;
                    temp.type = IF_;
                    temp.instructions_inside = $8->size();
                    temp.comparator = *$4; delete $4;
                    $$->insert($$->begin(), temp);
                }
            | WHILE '(' VARIABLE ',' ASSIGNMENT ')' INSTRUCTIONS {
                    $$ = $7;
                    if(*$3 != (*$5)[0].var) { return yyerror("wrong second argument in WHILE"); }
                    $$->insert($$->begin(), $5->begin(), $5->end()); delete $5;
                    Instruction temp;
                    temp.type = WHILE_;
                    temp.instructions_inside += 1;
                    temp.var = *$3; delete $3;
                    $$->insert($$->begin(), temp);
                }
            | WHILE '(' VARIABLE ',' ASSIGNMENT ')' '{' INSTRUCTIONS_MULTI '}' {
                    $$ = $8;
                    if(*$3 != (*$5)[0].var) { return yyerror("wrong second argument in WHILE"); }
                    $$->insert($$->begin(), $5->begin(), $5->end()); delete $5;
                    Instruction temp;
                    temp.type = WHILE_;
                    temp.instructions_inside = $8->size();
                    temp.var = *$3; delete $3;
                    $$->insert($$->begin(), temp);
                }
            ;

/*---- Rules - ASSIGNMENT ----*/
ASSIGNMENT : VARNAME '=' EQUATION {
                variables[*$1];
                $$ = new std::vector<Instruction>(1);
                (*$$)[0].equations.push_back(*$3); delete $3;
                (*$$)[0].type = ASSIGNMENT_;
                (*$$)[0].var = *$1; delete $1;
		    }
           ;

/*---- Rules - EQUATION ----*/
EQUATION : NUMBER {
        $$ = new Equation();
        ($$->elements.end()-1)->val = $1;
    }
  | '-' NUMBER {
        $$ = new Equation();
        ($$->elements.end()-1)->val = -$2;
    }
  | VARIABLE {
        $$ = new Equation();
        ($$->elements.end()-1)->var = *$1 + "+"; delete $1;
    }
  | '-' VARIABLE {
        $$ = new Equation();
        ($$->elements.end()-1)->var = *$2 + "-"; delete $2;
    }
  | EQUATION OPERATOR NUMBER {
        $$->elements_size_increase();
        ($$->elements.end()-2)->operation = *$2; delete $2;
        ($$->elements.end()-1)->val = $3;
    }
  | EQUATION OPERATOR '-' NUMBER {
        $$->elements_size_increase();
        ($$->elements.end()-2)->operation = *$2; delete $2;
        ($$->elements.end()-1)->val = -$4;
    }
  | EQUATION OPERATOR VARIABLE {
        $$->elements_size_increase();
        ($$->elements.end()-2)->operation = *$2; delete $2;
        ($$->elements.end()-1)->var = *$3 + "+"; delete $3;
    }
  | EQUATION OPERATOR '-' VARIABLE {
        $$->elements_size_increase();
        ($$->elements.end()-2)->operation = *$2; delete $2;
        ($$->elements.end()-1)->var = *$4 + "-"; delete $4;
    }
  ;

/*---- Rules - VARIABLE ----*/
VARIABLE : VARNAME { 
                if(check_variable_declaration(*$1) == 1) { return 1; }
                $$ = $1;
            }
         ;
%%

/*
 * Checks if variable is declared.
 *
 * @pa variableName Name of variable to check.
 * @return Comparison result.
*/
int check_variable_declaration(const std::string& variableName) {
        if(variables.find(variableName) == variables.end()) {
        const std::string message("variable undeclared " + variableName);
        return yyerror(message.c_str());
    }
    return 0;
}

//---- Instruction execution functions

/*
 * Executes comparison between left and right operands.
 *
 * @param left Left operand.
 * @param operation comparator.
 * @param Right operand.
 * @return Comparison result.
*/
bool compare (const double& left, const std::string& comparator, const double& right) {
    if(comparator == "==") { return left == right; }
    else if(comparator == "!=") { return left != right; }
    else if(comparator == ">")  { return left >  right; }
    else if(comparator == ">=") { return left >= right; }
    else if(comparator == "<")  { return left <  right; }
    else if(comparator == "<=") { return left <= right; }
    return false;
}

/*
 * Returns variable value.
 *
 * @param variableName Name of variable.
 * @return Variable value.
*/
double get_variable_value(const std::string& variableName){
    std::string temp_var = variableName;
    const char var_sign = *(temp_var.end()-1);
    temp_var.pop_back();
    
    double result = variables[temp_var];
    if(var_sign == '-') { result = -result; }
    return result;
}

/*
 * Selects action for instruction type and executes it.
 *
 * @param instructions Set of instructions to execute.
 * @param i Current position in set.
 * @param i_ref Changeable position. Used in recurrence to prevent multiple instruction executions. 
 * @return void.
*/
void execute_instruction(std::vector<Instruction>& instructions, const int i, int& i_ref) {
    switch(instructions[i].type) {

        case ASSIGNMENT_ : {
            variables[instructions[i].var] = instructions[i].calculate(0);
            if(debug) { std::cout << "Variable " << instructions[i].var << " has value of " << variables[instructions[i].var] << "\n"; }
            break;
        } //end ASSIGN


        case PRINT_ : {
            std::cout << ( debug? "PRINT: " : "")  << instructions[i].calculate(0) << "\n";
            break;
        } //end PRINT


        case IF_ : {
            const double left = instructions[i].calculate(0);
            const double right = instructions[i].calculate(1);
            
            if(debug) { std::cout << left << " " + instructions[i].comparator + " " << right << ": "; }
            i_ref += 1 + instructions[i].instructions_inside;
            if(compare(left, instructions[i].comparator, right)) {
                if(debug) { std::cout << "TRUE\n"; }
                for(int j = i + 1; j < i + 1 + instructions[i].instructions_inside; j++) {
                    execute_instruction(instructions, j, j);
                }
            }
            else { if(debug) { std::cout << "FALSE\n"; } }
            break;
        } //end IF


        case WHILE_ : {
            if(debug) { std::cout << "\nLoop start\n"; }
            const std::string var = instructions[i].var;
            i_ref += instructions[i].instructions_inside;
            while(variables[var] != 0) {
                for(int j = i + 2; j < i + 1 + instructions[i].instructions_inside; j++) {
                    /*std::cout << "Inside: " << instructions[i].instructions_inside << '\n';
                    std::cout << "I: " << i << '\n';
                    std::cout << "J: " << j << '\n';
                    std::cout << "J limit: " << i + 2 + instructions[i].instructions_inside << '\n';
                    std::cout << "i_ref: " << i_ref << '\n';*/
                    execute_instruction(instructions, j, j);
                }
                //std::cout << "Execution finish\n";
                variables[var] = instructions[i + 1].calculate(0);
                if(debug) { std::cout << "Variable " << var << " has value of " << variables[var] << "\n"; }
            }
            if(debug) { std::cout << "Loop end\n\n"; }
            break;
        } //end WHILE

    } //end switch
    dummy = 0;
}
