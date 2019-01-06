%{
    #include "structs_interpreter.hpp"
    #include <stack>
    #include <algorithm>
	#include <iostream>
    #include <iomanip>
    #include <map>
    #include <math.h>

    //---- Deklaracje funkcji do wykorzystania w pliku lex
	int yylex();
    int yywrap();
	int yyerror(const char*);

    //---- Stałe globalne
    static const std::map<std::string, int8_t> priorities = {
        { ""  , 0 }, { "+" , 0 }, { "-" , 0 },
        { "*" , 1 }, { "/" , 2 }, { "^" , 3 }
    }; //Wykorzystywane w kolejności wykonywania działan

    //---- Zmienne globalne
    std::map<std::string, double> variables;
    static int dummy = 0;
    unsigned int line = 1;
    unsigned int column = 1;
 
    //---- Funkcje
    inline int check_variable_declaration(const std::string& var);
    inline double calculate_equation(const std::vector<Element>& elements);
    inline void execute_instruction(std::vector<Instruction>& instructions, const int i, int& i_ref);
%}

%union {
    double fVal;
    std::string* strName;
    std::vector<Instruction>* Instructions;
    std::vector<Element>* Elements;
};

/*---- Nieterminale ----*/
%start PROGRAM
%type<Elements> EQUATION
%type<Instructions> ASSIGNMENT
%type<Instructions> INSTRUCTIONS
%type<Instructions> INSTRUCTIONS_MULTI
%type<strName> VARIABLE
%type<strName> OPERATOR

/*---- Tokeny Z Typem ----*/
%token <fVal> NUMBER
%token <strName> VARNAME
//%token <strName> OPERATOR
%token <strName> COMPARATOR

/*---- Tokeny Bez Typu ----*/
%token UNK
%token PRINT
%token IF
%token WHILE
%token NEWLINE

%%

/*---- Reguły - S ----*/
PROGRAM : PROGRAM INSTRUCTIONS ';' {
                std::cout << std::setprecision(15);
                if(!$2->empty()){ execute_instruction(*$2, 0, dummy); }
                delete $2;
            }
        | PROGRAM INSTRUCTIONS { return yyerror("expected ';' at the end of instruction"); }
        | PROGRAM INSTRUCTIONS NEWLINE { line--; column--; return yyerror("expected ';' at the end of instruction"); }
        | PROGRAM NEWLINE { column = 1; }
        | /*nic*/
        ;

/*---- Reguły - OPERATOR ----*/
OPERATOR : '+' { $$ = new std::string("+"); }
         | '-' { $$ = new std::string("-"); }
         | '*' { $$ = new std::string("*"); }
         | '/' { $$ = new std::string("/"); }
         | '^' { $$ = new std::string("^"); }
         ;

/*---- Reguły - INSTRUCTIONS_MULTI ----*/
INSTRUCTIONS_MULTI : INSTRUCTIONS_MULTI INSTRUCTIONS ';' {
                        $$->insert($$->end(), $2->begin(), $2->end());
                    }
                   | INSTRUCTIONS_MULTI NEWLINE { column = 1; }
                   | /*nic*/{
                       $$ = new std::vector<Instruction>();
                    }
                   ;

/*---- Reguły - INSTRUCTIONS ----*/
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
                    $$->insert($$->begin(), $5->begin(), $5->end()); delete $5;
                    Instruction temp;
                    temp.type = WHILE_;
                    temp.var = *$3; delete $3;
                    $$->insert($$->begin(), temp);
                }
            | WHILE '(' VARIABLE ',' ASSIGNMENT ')' '{' INSTRUCTIONS_MULTI '}' {
                    $$ = $8;
                    $$->insert($$->begin(), $5->begin(), $5->end()); delete $5;
                    Instruction temp;
                    temp.type = WHILE_;
                    temp.instructions_inside = $8->size();
                    temp.var = *$3; delete $3;
                    $$->insert($$->begin(), temp);
                }
            ;

/*---- Reguły - ASSIGNMENT ----*/
ASSIGNMENT : VARNAME '=' EQUATION {
                variables[*$1];
                $$ = new std::vector<Instruction>(1);
                (*$$)[0].elements.push_back(*$3); delete $3;
                (*$$)[0].type = ASSIGNMENT_;
                (*$$)[0].var = *$1; delete $1;
		    }
           ;

/*---- Reguły - EQUATION ----*/
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

/*---- Reguły - VARIABLE ----*/
VARIABLE : VARNAME { 
                if(check_variable_declaration(*$1) == 1) { return 1; }
                $$ = $1;
            }
         ;
%%

int check_variable_declaration(const std::string& var) {
        if(variables.find(var) == variables.end()) {
        const std::string message("variable undeclared " + std::string(var));
        return yyerror( message.c_str() );
    }
    return 0;
}

//---- Wykonywanie Instrukcji

bool compare (const double& left, const std::string& comparator, const double& right){
    if(comparator == "==") { return left == right; }
    else if(comparator == ">")  { return left >  right; }
    else if(comparator == ">=") { return left >= right; }
    else if(comparator == "<")  { return left <  right; }
    else if(comparator == "<=") { return left <= right; }
    return false;
}

void calculate_equation_operation(double& leftValue, const std::string& operation, const double& rightValue) {
    //---- Dodawanie
    if(operation == "+") { leftValue += rightValue; }

    //---- Odejmowanie
    else if(operation == "-") { leftValue -= rightValue; }

    //---- Mnozenie
    else if(operation == "*") { leftValue *= rightValue; }

    //---- Dzielenie
    else if(operation == "/") { leftValue /= rightValue; }

    //---- Potegowanie
    else if(operation == "^") { leftValue = pow(leftValue,rightValue); }
}

double calculate_equation(const std::vector<Element>& elements){
    double result = 0;     //Zmienna przechowująca wynik obliczen
    double tempResult = 0; //Zmienna przechowująca wynik tymczasowych obliczen (np. gdy po dodawaniu sa mnozenia)
    double val = 0; //Zmienna przechoująca wartość prawego argumentu

    //Stos części do wykonania później (wykorzystany przy kolejności wykonywania działa)
    std::stack<Element> instructionStack;

    //Przypisanie pierwszego argumentu do wyniku (później wykonywane są na nim operacje)
    if( elements[0].var.empty() ) { result = elements[0].val; }
    else { 
        std::string temp_var = elements[0].var;
        const char var_sign = *(temp_var.end()-1);
        temp_var.pop_back();
        result = variables[temp_var];
        if(var_sign == '-') { result = -result; }
    }

    //Pętla wykonywania
    for( int i = 0; i < elements.size() - 1; i++ ) {
        if( elements[i+1].var.empty() ){ val = elements[i+1].val; }
        //Jeśli argument jest zmienną to ściągamy jej wartość z mapy
        else {
            std::string temp_var = elements[i+1].var;
            const char var_sign = *(temp_var.end()-1);
            temp_var.pop_back();
            val = variables[temp_var];
            if(var_sign == '-') { val = -val; }
        }

        //Sprawdzanie priorytetów operatorów
        if( priorities.at(elements[i].operation) >= priorities.at(elements[i+1].operation) ) {
            if( instructionStack.empty() ) { //Dla pustego stosu wykoknujemy operację na wyniku
                calculate_equation_operation(result, elements[i].operation, val);
            }
            else { //Dla niepustego stosu wykonujemy operację na tymaczasowych wyniku
                calculate_equation_operation(tempResult, elements[i].operation, val);
            }
        }
        else { //Jeśli drugi operator jest wyższego priorytetu niż pierwszy
            tempResult = val;
            instructionStack.push(elements[i]);
        } //Koniec sprawdzania priorytetów

        //Sprawdzanie stosu
        while(!instructionStack.empty()){
            //Jeśli operator na stosie ma priorytet niemniejszy od operatora aktualnego to wykonujemy operację
            if( priorities.at(instructionStack.top().operation) >= priorities.at(elements[i + 1].operation) ) {
                if( instructionStack.size() > 1 ) { 
                    //Jeśli po operacji stos nie będzie pusty to wykonujemy ją
                    //pomiędzy wynikiem tymczasowym a argumentem na stosie
                    if( instructionStack.top().var.empty() ) { val = instructionStack.top().val; }
                    else { 
                        std::string temp_var = instructionStack.top().var;
                        const char var_sign = *(temp_var.end()-1);
                        temp_var.pop_back();
                        val = variables[temp_var];
                        if(var_sign == '-') { val = -val; }
                    }
                    calculate_equation_operation(tempResult, instructionStack.top().operation, val);
                }
                else { calculate_equation_operation(result, instructionStack.top().operation, tempResult); }

                instructionStack.pop();
                if(instructionStack.empty()) { tempResult = 0; }
            }
            else { break; }
        } //Koniec sprawdzania stosu
    } //Koniec pętli wykonywania
    return result;
}

void execute_instruction(std::vector<Instruction>& instructions, const int i, int& i_ref) {
    switch( instructions[i].type ){
        case ASSIGNMENT_ : {
            variables[instructions[i].var] = calculate_equation(instructions[i].elements[0]);
            std::cout << "Zmienna " << instructions[i].var << " ma wartosc " 
                      << variables[instructions[i].var] << "\n";
            break;
        } //end ASSIGN

        case PRINT_ : {
            std::cout << "PRINT: " << calculate_equation(instructions[i].elements[0]) << "\n";
            break;
        } //end PRINT

        case IF_ : {
            double left = calculate_equation(instructions[i].elements[0]);
            double right = calculate_equation(instructions[i].elements[1]);
            
            std::cout << left << " " + instructions[i].comparator + " " << right << ": ";
            i_ref += 1 + + instructions[i].instructions_inside;
            if(compare(left, instructions[i].comparator, right)){
                std::cout << "prawda\n";
                for(int j = i + 1; j < i + 1 + instructions[i].instructions_inside; j++) {
                    execute_instruction(instructions, j, j);
                }
            }
            else { std::cout << "falsz\n"; }
            break;
        } //end IF

        case WHILE_ : {
            std::cout << "\nPoczatek petli\n";
            //Spisanie nazwy zmiennej iteracyjnej
            const std::string var = instructions[i].var;
            i_ref += 2 + instructions[i].instructions_inside;
            while(variables[var] != 0){
                for(int j = i + 2; j < i + 2 + instructions[i].instructions_inside; j++) {
                    execute_instruction(instructions, j, j);
                }
                //Wykonanie instrukcji iteracyjnej pętli                
                variables[var] = calculate_equation(instructions[i + 1].elements[0]);
                std::cout << "Zmienna " << var << " ma wartosc " << variables[var] << "\n";
            }
            std::cout << "Koniec petli\n";
            break;
        } //end WHILE

    } //end switch
    dummy = 0;
}
