#ifndef STRUCTS_HPP
#define STRUCTS_HPP

#include <string>
#include <vector>
#include <map>
#include <stack>
#include <math.h>

enum OPERATIONS { ASSIGNMENT_, PRINT_, IF_, WHILE_ };

extern std::map<std::string, double> variables;
double get_variable_value(const std::string& variableName);

//---- Structs Definitions
struct Element {
	double val = 0;
	std::string var;
	std::string operation;

	Element() = default;
	Element(const double& val_) : val(val_) {}
};

//---- Classes Definitions
class Equation {
private:
	std::map<std::string, int8_t> priorities {
		{ ""  , 0 }, { "+" , 0 }, { "-" , 0 },
		{ "*" , 1 }, { "/" , 2 }, { "^" , 3 }
	}; //Used in order of operations

	/*
	 * Executes elemental calculation operation.
	 *
	 * @param left Left operand.
	 * @param operation Operator.
	 * @param Right operand.
	 * @return void.
	*/
	void calculate_operation(double& left, const std::string& operation, const double& right) const {
		//---- Addition
		if (operation == "+") { left += right; }

		//---- Subtraction
		else if (operation == "-") { left -= right; }

		//---- Multiplication
		else if (operation == "*") { left *= right; }

		//---- Division
		else if (operation == "/") { left /= right; }

		//---- Power
		else if (operation == "^") { left = pow(left, right); }
	}

public:
	std::vector<Element> elements = std::vector<Element>(1);

	Equation() = default;

	/*
	 * Increases size of elements by 1;
	 *
	 * @return void.
	*/
	void elements_size_increase() { elements.resize(elements.size() + 1); }

	/*
	 * Calculates given equation.
	 *
	 * @return Result of calculation.
	*/
	double calculate() const {
		double result = 0;
		double tempResult = 0; //Stores temporal result (eg. when multiplication occures after addition)
		double val = 0; //Stores right argument value

		//Stack of instructions to do late
		//Used int order of operations
		std::stack<Element> instructionStack;

		//Assigment of first argument to result (late operations are executed on it)
		if (elements[0].var.empty()) { result = elements[0].val; }
		else { result = get_variable_value(elements[0].var); }

		//Execution loop
		for (int i = 0; i < elements.size() - 1; i++) {

			if (elements[i + 1].var.empty()) { val = elements[i + 1].val; }

			//When argument is variable its value is read from variables map
			else { val = get_variable_value(elements[i + 1].var); }

			//Operators priority check
			//When first operator is more or equally important as the second operator
			//Operation is executed
			if (priorities.at(elements[i].operation) >= priorities.at(elements[i + 1].operation)) {
				//Stack empty - operations executed on result
				if (instructionStack.empty()) { calculate_operation(result, elements[i].operation, val); }
				//Stack not empty - operations executed on temporal result
				else { calculate_operation(tempResult, elements[i].operation, val); }
			}
			//When first operator is less important than second
			//Operation is pushed on the stack
			else {
				tempResult = val;
				instructionStack.push(elements[i]);
			} //End priority check

			//Stack check
			while (!instructionStack.empty()) {
				//When first operator is more or equally important as the second operator
				if (priorities.at(instructionStack.top().operation) >= priorities.at(elements[i + 1].operation)) {
					if (instructionStack.size() > 1) {
						//If stack won't be empty after operation execution
						//operation is executed on temporal result and argument on stack
						if (instructionStack.top().var.empty()) { val = instructionStack.top().val; }
						else { val = get_variable_value(instructionStack.top().var); }
						calculate_operation(tempResult, instructionStack.top().operation, val);
					}
					else { calculate_operation(result, instructionStack.top().operation, tempResult); }

					instructionStack.pop();
					if (instructionStack.empty()) { tempResult = 0; }
				}
				else { break; }
			} //End stack check
		
		} //End execution loop

		return result;
	}
};

class Instruction {
public:
	enum OPERATIONS type;
	std::string var;
	std::string comparator;
	std::vector<Equation> equations;
	unsigned int instructions_inside = 1;

	Instruction() = default;

	/*
	 * Calculates given equation.
	 *
	 * @param Number of equation to calculate.
	 * @return Result of calculation.
	*/
	double calculate(const unsigned int& equationNum) {
		return equations[equationNum].calculate();
	}
};

#endif
