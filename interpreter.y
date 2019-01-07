%{
    #include "structs_interpreter.hpp"
    #include <stack>
	#include <iostream>
    #include <iomanip>
    #include <map>
    #include <math.h>

    //---- Function declarations to use in lex file
	int yylex();
	int yyerror(const char*);

    //---- Global constants
    static const std::map<std::string, int8_t> priorities = {
        { ""  , 0 }, { "+" , 0 }, { "-" , 0 },
        { "*" , 1 }, { "/" , 2 }, { "^" , 3 }
    }; //Used in order of operations

    //---- Global variables
    std::map<std::string, double> variables;
    static int dummy = 0;
    unsigned int line = 1;
    unsigned int column = 1;
    bool debug;
 
    //---- Functions
    inline int check_variable_declaration(const std::string& variableName);
    inline double calculate_equation(const std::vector<Element>& elements);
    inline void execute_instruction(std::vector<Instruction>& instructions, const int i, int& i_ref);
%}

%union {
    double fVal;
    std::string* strName;
    std::vector<Instruction>* Instructions;
    std::vector<Element>* Elements;
};

/*---- Nonterminals ----*/
%start PROGRAM
%type<Elements> EQUATION
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
                    (*$$)[0].elements.push_back(*$3); delete $3;
                    (*$$)[0].type = PRINT_;
                }
		    | ASSIGNMENT { $$ = $1; }
            | IF '(' EQUATION COMPARATOR EQUATION ')' INSTRUCTIONS {
                    $$ = $7;
                    Instruction temp;
                    temp.elements.push_back(*$3); delete $3;
                    temp.elements.push_back(*$5); delete $5;
                    temp.type = IF_;
                    temp.comparator = *$4; delete $4;
                    $$->insert($$->begin(), temp);
                }
            | IF '(' EQUATION COMPARATOR EQUATION ')' '{' INSTRUCTIONS_MULTI '}' {
                    $$ = $8;
                    Instruction temp;
                    temp.elements.push_back(*$3); delete $3;
                    temp.elements.push_back(*$5); delete $5;
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
                (*$$)[0].elements.push_back(*$3); delete $3;
                (*$$)[0].type = ASSIGNMENT_;
                (*$$)[0].var = *$1; delete $1;
		    }
           ;

/*---- Rules - EQUATION ----*/
EQUATION : NUMBER {
        $$ = new std::vector<Element>(1);
        ($$->end()-1)->val = $1;
    }
  | '-' NUMBER {
        $$ = new std::vector<Element>(1);
        ($$->end()-1)->val = -$2;
    }
  | VARIABLE {
        $$ = new std::vector<Element>(1);
        ($$->end()-1)->var = *$1 + "+"; delete $1;
    }
  | '-' VARIABLE {
        $$ = new std::vector<Element>(1);
        ($$->end()-1)->var = *$2 + "-"; delete $2;
    }
  | EQUATION OPERATOR NUMBER {
        $$->resize($$->size()+1);
        ($$->end()-2)->operation = *$2; delete $2;
        ($$->end()-1)->val = $3;
    }
  | EQUATION OPERATOR '-' NUMBER {
        $$->resize($$->size()+1);
        ($$->end()-2)->operation = *$2; delete $2;
        ($$->end()-1)->val = -$4;
    }
  | EQUATION OPERATOR VARIABLE {
        $$->resize($$->size()+1);
        ($$->end()-2)->operation = *$2; delete $2;
        ($$->end()-1)->var = *$3 + "+"; delete $3;
    }
  | EQUATION OPERATOR '-' VARIABLE {
        $$->resize($$->size()+1);
        ($$->end()-2)->operation = *$2; delete $2;
        ($$->end()-1)->var = *$4 + "-"; delete $4;
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
 * Executes elemental calculation operation.
 *
 * @param left Left operand.
 * @param operation Operator.
 * @param Right operand.
 * @return void.
*/
void calculate_equation_operation(double& left, const std::string& operation, const double& right) {
    //---- Addition
    if(operation == "+") { left += right; }

    //---- Subtraction
    else if(operation == "-") { left -= right; }

    //---- Multiplication
    else if(operation == "*") { left *= right; }

    //---- Division
    else if(operation == "/") { left /= right; }

    //---- Power
    else if(operation == "^") { left = pow(left, right); }
}

double get_variable_value(const std::string& variableName){
    double result;
    std::string temp_var = variableName;
    const char var_sign = *(temp_var.end()-1);
    temp_var.pop_back();
    result = variables[temp_var];
    if(var_sign == '-') { result = -result; }
    return result;
}

/*
 * Calculates given equation.
 *
 * @param elements Set elements to execute calculation on.
 * @return Result of calculation.
*/
double calculate_equation(const std::vector<Element>& elements) {
    double result = 0;
    double tempResult = 0; //Stores temporal result (eg. when multiplication occures after addition)
    double val = 0; //Stores right argument value

    //Stack of instructions to do late
    //Used int order of operations
    std::stack<Element> instructionStack;

    //Assigment of first argument to result (late operations are executed on it)
    if(elements[0].var.empty()) { result = elements[0].val; }
    else { result = get_variable_value(elements[0].var); }

    //Execution loop
    for(int i = 0; i < elements.size() - 1; i++) {
        if(elements[i+1].var.empty()) { val = elements[i+1].val; }

        //When argument is variable its value is read from variables map
        else { val = get_variable_value(elements[i+1].var); }

        //Operators priority check
        //When first operator is more or equally important as the second operator
        //Operation is executed
        if(priorities.at(elements[i].operation) >= priorities.at(elements[i+1].operation)) {
            //Stack empty - operations executed on result
            if(instructionStack.empty()) { calculate_equation_operation(result, elements[i].operation, val); }
            //Stack not empty - operations executed on temporal result
            else { calculate_equation_operation(tempResult, elements[i].operation, val); }
        }
        //When first operator is less important than second
        //Operation pushed on the stack
        else {
            tempResult = val;
            instructionStack.push(elements[i]);
        } //End priority check

        //Stack check
        while(!instructionStack.empty()) {
            //When first operator is more or equally important as the second operator
            if(priorities.at(instructionStack.top().operation) >= priorities.at(elements[i + 1].operation)) {
                if(instructionStack.size() > 1) { 
                    //If stack won't be empty after operation execution
                    //operation is executed on temporal result and argument on stack
                    if(instructionStack.top().var.empty()) { val = instructionStack.top().val; }
                    else { val = get_variable_value(instructionStack.top().var); }
                    calculate_equation_operation(tempResult, instructionStack.top().operation, val);
                }
                else { calculate_equation_operation(result, instructionStack.top().operation, tempResult); }

                instructionStack.pop();
                if(instructionStack.empty()) { tempResult = 0; }
            }
            else { break; }
        } //End stack check
    } //End execution loop
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
            variables[instructions[i].var] = calculate_equation(instructions[i].elements[0]);
            if(debug) { std::cout << "Variable " << instructions[i].var << " has value of " << variables[instructions[i].var] << "\n"; }
            break;
        } //end ASSIGN

        case PRINT_ : {
            std::cout << ( debug? "PRINT: " : "")  << calculate_equation(instructions[i].elements[0]) << "\n";
            break;
        } //end PRINT

        case IF_ : {
            const double left = calculate_equation(instructions[i].elements[0]);
            const double right = calculate_equation(instructions[i].elements[1]);
            
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
            i_ref += 2 + instructions[i].instructions_inside;
            while(variables[var] != 0) {
                for(int j = i + 2; j < i + 2 + instructions[i].instructions_inside; j++) {
                    execute_instruction(instructions, j, j);
                }
                variables[var] = calculate_equation(instructions[i + 1].elements[0]);
                if(debug) { std::cout << "Variable " << var << " has value of " << variables[var] << "\n"; }
            }
            if(debug) { std::cout << "Loop end\n"; }
            break;
        } //end WHILE

    } //end switch
    dummy = 0;
}
