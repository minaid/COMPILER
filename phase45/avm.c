#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "icode.h"
#include "fcode.h"

enum avm_memcell_t {
  number_m = 0,
  string_m = 1,
  bool_m = 2,
  table_m = 3,
  userfunc_m = 4,
  libfunc_m = 5,
  nil_m = 6,
  undef_m = 7
};

struct avm_table;
struct avm_memcell {
  enum avm_memcell_t type;
  union {
    double numVal;
    char *strVal;
    unsigned char boolVal;
    struct avm_table *tableVal;
    unsigned funcVal;
    char *libfuncVal;
  } data;
};

double *numConsts = NULL;
unsigned totalNumConsts = 0;
char **stringConsts;
unsigned totalStringConsts = 0;
char **namedLibfuncs = NULL;
unsigned totalNamedLibfuncs = 0;
struct userfunc *userFuncs;
unsigned totalUserFuncs = 0;

double consts_getnumber(unsigned index){ return numConsts[index]; }
char *consts_getstring(unsigned index){ return stringConsts[index]; }
char *libfuncs_getused(unsigned index){ return namedLibfuncs[index]; }

unsigned char executionFinished = 0;
unsigned int pc = 0;
unsigned int currLine = 0;
unsigned int codeSize = 0;
struct instruction *code = NULL;
#define AVM_ENDING_PC codeSize
#define AVM_STACKSIZE 4096
#define AVM_STACKENV_SIZE 4
#define AVM_NUMACTUALS_OFFSET   +4
#define AVM_SAVEDPC_OFFSET      +3
#define AVM_SAVEDTOP_OFFSET     +2
#define AVM_SAVEDTOPSP_OFFSET   +1
struct avm_memcell ax, bx, cx;
struct avm_memcell retval;
unsigned top = 2000, topsp = 2000;
unsigned totalActuals = 0;

#define AVM_MAX_INSTRUCTIONS (unsigned)nop_v

char *typeStrings[] = { "number", "string", "bool", "table", "userfunc", "libfunc", "nil", "undef" };

struct avm_memcell *avm_translate_operand(struct vmarg *arg, struct avm_memcell *reg);

struct avm_memcell stack[AVM_STACKSIZE];

void avm_initstack(void){
	unsigned i;
	for(i = 0; i < AVM_STACKSIZE; ++i){
		memset(&stack[i], 0, sizeof(struct avm_memcell));
		stack[i].type = undef_m;
	}
}

typedef void (*library_func_t)(void);
typedef void (*execute_func_t)(struct instruction *);

void execute_assign(struct instruction *);
void execute_arithmetic(struct instruction *instr);
#define execute_add execute_arithmetic
#define execute_sub execute_arithmetic
#define execute_mul execute_arithmetic
#define execute_div execute_arithmetic
#define execute_mod execute_arithmetic
void execute_uminus(struct instruction *i){assert(0);} // den prepei na doume tetoies entoles
void execute_and(struct instruction *i){assert(0);} // den prepei na doume tetoies entoles
void execute_or(struct instruction *i){assert(0);} // den prepei na doume tetoies entoles
void execute_not(struct instruction *i){assert(0);} // den prepei na doume tetoies entoles
void execute_jmp(struct instruction *);
void execute_jeq(struct instruction *);
void execute_jne(struct instruction *);
void execute_logical(struct instruction *);
#define execute_jle execute_logical
#define execute_jge execute_logical
#define execute_jlt execute_logical
#define execute_jgt execute_logical
void execute_call(struct instruction *);
void execute_pusharg(struct instruction *);
void execute_funcenter(struct instruction *i){assert(0);} // den to kaname
void execute_funcexit(struct instruction *);
void execute_newtable(struct instruction *i){assert(0);} // den to kaname
void execute_tablegetelem(struct instruction *i){assert(0);} // den to kaname
void execute_tablesetelem(struct instruction *i){assert(0);} // den ta kaname
void execute_nop(struct instruction *i){} // den kanei tpt

execute_func_t executeFuncs[] = {
	execute_assign,
	execute_add,
	execute_sub,
	execute_mul,
	execute_div,
	execute_mod,
	execute_uminus,
	execute_and,
	execute_or,
	execute_not,
	execute_jmp,
	execute_jeq,
	execute_jne,
	execute_jle,
	execute_jge,
	execute_jlt,
	execute_jgt,
	execute_call,
	execute_pusharg,
	execute_funcenter,
	execute_funcexit,
	execute_newtable,
	execute_tablegetelem,
	execute_tablesetelem,
	execute_nop
};

typedef void (*memclear_func_t)(struct avm_memcell *);

void memclear_string(struct avm_memcell *m){
	assert(m->data.strVal);
	free(m->data.strVal);
}

void memclear_table(struct avm_memcell *m){
	assert(m->data.tableVal);
	/* decrement reference count */
}

memclear_func_t memclearFuncs[] = {
	0,
	memclear_string,
	0,
	memclear_table,
	0,
	0,
	0,
	0
};

void avm_memcellclear(struct avm_memcell *m){
	if(m->type != undef_m){
		memclear_func_t f = memclearFuncs[m->type];
		if(f)
			(*f)(m);
		m->type = undef_m;
	}
}

typedef char *(*tostring_func_t)(struct avm_memcell *);

char *number_tostring(struct avm_memcell *a){ 
	char tmp[100];
	sprintf(tmp, "%lf", a->data.numVal);
	return strdup(tmp);
}

char *string_tostring(struct avm_memcell *a){
	return strdup(a->data.strVal);
}

char *bool_tostring(struct avm_memcell *a){
	return strdup((a->data.boolVal == 1)?("TRUE"):("FALSE"));	
}

char *table_tostring(struct avm_memcell *a){
	assert(0);
	return NULL;
}

char *userfunc_tostring(struct avm_memcell *a){
	assert(0);
	return NULL;	
}

char *libfunc_tostring(struct avm_memcell *a){
	return strdup(a->data.libfuncVal);
}

char *nil_tostring(struct avm_memcell *a){
	return strdup("NIL");	
}

char *undef_tostring(struct avm_memcell *a){
	return strdup("UNDEF");	
}

tostring_func_t tostringFuncs[] = {
	number_tostring,
	string_tostring,
	bool_tostring,
	table_tostring,
	userfunc_tostring,
	libfunc_tostring,
	nil_tostring,
	undef_tostring
};

char *avm_tostring(struct avm_memcell *a){
	return (*tostringFuncs[a->type])(a);
}

typedef unsigned char (*tobool_func_t)(struct avm_memcell *m);

unsigned char number_tobool(struct avm_memcell *m){ return m->data.numVal != 0; }
unsigned char string_tobool(struct avm_memcell *m){ return m->data.strVal[0] != 0; }
unsigned char bool_tobool(struct avm_memcell *m){ return m->data.boolVal; }
unsigned char table_tobool(struct avm_memcell *m){ return 1; }
unsigned char userfunc_tobool(struct avm_memcell *m){ return 1; }
unsigned char libfunc_tobool(struct avm_memcell *m){ return 1; }
unsigned char nil_tobool(struct avm_memcell *m){ return 0; }
unsigned char undef_tobool(struct avm_memcell *m){ assert(0); return 0; }

tobool_func_t toboolFuncs[] = {
	number_tobool,
	string_tobool,
	bool_tobool,
	table_tobool,
	userfunc_tobool,
	libfunc_tobool,
	nil_tobool,
	undef_tobool
};

unsigned char avm_tobool(struct avm_memcell *m){
	assert(m->type >= 0 && m->type <= undef_m);
	return (*toboolFuncs[m->type])(m);
}

void execute_jmp(struct instruction *instr){
  assert(instr->result.type == label_a);
	if(!executionFinished)
  	pc = instr->result.val;
}

void execute_jeq(struct instruction *instr){
  assert(instr->result.type == label_a);

  struct avm_memcell *rv1 = avm_translate_operand(&instr->arg1, &ax);
  struct avm_memcell *rv2 = avm_translate_operand(&instr->arg2, &bx);

  unsigned char result = 0;

  if(rv1->type == undef_m || rv2->type == undef_m){
    printf("undef involved in equality!\n");
    executionFinished = 1;
  }else if(rv1->type == nil_m || rv2->type == nil_m){
    result = (rv1->type == nil_m) && (rv2->type == nil_m);
  }else if(rv1->type == bool_m || rv2->type == bool_m){
    result = (avm_tobool(rv1) == avm_tobool(rv2));
  }else if(rv1->type != rv2->type){
    printf("%s == %s is illegal!\n", typeStrings[rv1->type], typeStrings[rv2->type]);
    executionFinished = 1;
  }else{
    switch(rv1->type){
      case number_m: { 
				result = rv1->data.numVal == rv2->data.numVal; 
				break; 
			}
      case string_m: { 
				result = !strcmp(rv1->data.strVal, rv2->data.strVal); 
				break; 
			}
      case bool_m: { 
				result = rv1->data.boolVal == rv2->data.boolVal; 
				break; 
			}
      default: 
				assert(0);
    }
  }

  if(!executionFinished && result)
    pc = instr->result.val;
}

void execute_jne(struct instruction *instr){
  assert(instr->result.type == label_a);

  struct avm_memcell *rv1 = avm_translate_operand(&instr->arg1, &ax);
  struct avm_memcell *rv2 = avm_translate_operand(&instr->arg2, &bx);

  unsigned char result = 0;

  if(rv1->type == undef_m || rv2->type == undef_m){
    printf("undef involved in equality!\n");
    executionFinished = 1;
  }else if(rv1->type == nil_m || rv2->type == nil_m){
    result = (rv1->type == nil_m) && (rv2->type == nil_m);
  }else if(rv1->type == bool_m || rv2->type == bool_m){
    result = (avm_tobool(rv1) == avm_tobool(rv2));
  }else if(rv1->type != rv2->type){
    printf("%s == %s is illegal!\n", typeStrings[rv1->type], typeStrings[rv2->type]);
    executionFinished = 1;
  }else{
    switch(rv1->type){
      case number_m: { 
				result = rv1->data.numVal != rv2->data.numVal; 
				break; 
			}
      case string_m: { 
				result = strcmp(rv1->data.strVal, rv2->data.strVal); 
				break; 
			}
      case bool_m: { 
				result = rv1->data.boolVal != rv2->data.boolVal; 
				break; 
			}
      default: 
				assert(0);
    }
  }

  if(!executionFinished && result)
    pc = instr->result.val;
}

typedef unsigned char (*logical_func_t)(double x, double y);

unsigned char jle_impl(double x, double y){ return x <= y; }
unsigned char jge_impl(double x, double y){ return x >= y; }
unsigned char jlt_impl(double x, double y){ return x < y; }
unsigned char jgt_impl(double x, double y){ return x > y; }

logical_func_t logicalFuncs[] = {
	jle_impl,
	jge_impl,
	jlt_impl,
	jgt_impl
};

void execute_logical(struct instruction *instr){
	struct avm_memcell *rv1 = avm_translate_operand(&instr->arg1, &ax);
	struct avm_memcell *rv2 = avm_translate_operand(&instr->arg2, &bx);
	unsigned char cmp;

//	assert(lv && (&stack[0] <= lv && &stack[top] > lv || lv == &retval));
	assert(rv1 && rv2);

	if(rv1->type != number_m || rv2->type != number_m){
		printf("not a number in comparison!\n");
		executionFinished = 1;
	}else{
		logical_func_t op = logicalFuncs[instr->opcode - jle_v];
		cmp = (*op)(rv1->data.numVal, rv2->data.numVal);
		if(cmp == 1)
			pc = instr->result.val;
	}
}

typedef double (*arithmetic_func_t)(double x, double y);

double add_impl(double x, double y){ return x + y; }
double sub_impl(double x, double y){ return x - y; }
double mul_impl(double x, double y){ return x * y; }
double div_impl(double x, double y){ return x / y; }
double mod_impl(double x, double y){ return (unsigned)x % (unsigned)y; }

arithmetic_func_t arithmeticFuncs[] = {
	add_impl,
	sub_impl,
	mul_impl,
	div_impl,
	mod_impl
};

void execute_arithmetic(struct instruction *instr){
	struct avm_memcell *lv = avm_translate_operand(&instr->result, NULL);
	struct avm_memcell *rv1 = avm_translate_operand(&instr->arg1, &ax);
	struct avm_memcell *rv2 = avm_translate_operand(&instr->arg2, &bx);

	//assert(lv && (&stack[0] <= lv && &stack[top] > lv || lv == &retval));
	assert(rv1 && rv2);

	if(rv1->type != number_m || rv2->type != number_m){
		printf("not a number in arithmetic!\n");
		executionFinished = 1;
	}else{
		arithmetic_func_t op = arithmeticFuncs[instr->opcode - add_v];
		avm_memcellclear(lv);
		lv->type = number_m;
		lv->data.numVal = (*op)(rv1->data.numVal, rv2->data.numVal);
	}
}

void avm_assign(struct avm_memcell *lv, struct avm_memcell *rv){
	if(lv == rv)
		return;

	if(lv->type == table_m && rv->type == table_m && lv->data.tableVal == rv->data.tableVal)
		return;

	if(rv->type == undef_m)
		printf("assigning from undef content!\n");

	avm_memcellclear(lv);

	memcpy(lv, rv, sizeof(struct avm_memcell));

	if(lv->type == string_m){
		lv->data.strVal = strdup(rv->data.strVal);
	}else if(lv->type == table_m){
		/* increase reference count */
	}
}

void execute_assign(struct instruction *instr){
	struct avm_memcell *lv = avm_translate_operand(&instr->result, NULL);
	struct avm_memcell *rv = avm_translate_operand(&instr->arg1, &ax);

	//assert(lv && (&stack[0] <= lv && &stack[top] > lv || lv == &retval));
	assert(rv);

	avm_assign(lv, rv);
}

void avm_dec_top(void){
	if(!top){
		printf("STACK OVERFLOW!\n");
		executionFinished = 1;
	}else{
		--top;
	}
}

void avm_push_envvalue(unsigned val){
	stack[top].type = number_m;
	stack[top].data.numVal = val;
	avm_dec_top();
}

void avm_callsaveenvironment(void){
	avm_push_envvalue(totalActuals);
	avm_push_envvalue(pc + 1);
	avm_push_envvalue(top + totalActuals + 2);
	avm_push_envvalue(topsp);
}

void execute_pusharg(struct instruction *instr){
	struct avm_memcell *arg = avm_translate_operand(&instr->arg1, &ax);
	assert(arg);

	avm_assign(&stack[top], arg);
	++totalActuals;
	avm_dec_top();
}

unsigned avm_get_envvalue(unsigned i){
	assert(stack[i].type == number_m);
	unsigned val = (unsigned)stack[i].data.numVal;
	assert(stack[i].data.numVal == ((double)val));
	return val;
}

unsigned avm_totalactuals(void){
  return avm_get_envvalue(topsp + AVM_NUMACTUALS_OFFSET);
}

struct avm_memcell *avm_getactual(unsigned i){
  assert(i < avm_totalactuals());
  return &stack[topsp + AVM_STACKENV_SIZE + 1 + i];
}

void libfunc_print(void){
	unsigned i;
	unsigned n = avm_totalactuals();
	for(i = 0; i < n; ++i){
		char *s = avm_tostring(avm_getactual(i));
		puts(s);
		free(s);
	}
}

void execute_funcexit(struct instruction *instr){
	unsigned oldTop = top;

	top = avm_get_envvalue(topsp + AVM_SAVEDTOP_OFFSET);
	pc = avm_get_envvalue(topsp + AVM_SAVEDPC_OFFSET);
	topsp = avm_get_envvalue(topsp + AVM_SAVEDTOPSP_OFFSET);

	while(++oldTop <= top)
		avm_memcellclear(&stack[oldTop]);
}

void avm_calllibfunc(char *id){
	library_func_t f = libfunc_print; //avm_getlibraryfunc(id); // panta kalei thn print -- ara ypostirizoume apo libfunc mono thn prit
	if(!f){
		printf("ERROR wrong library func %s\n", id);
		executionFinished = 1;
	}else{
		topsp = top;
		totalActuals = 0;
		(*f)();
		if(!executionFinished)
			execute_funcexit(NULL);
	}
}

void execute_call(struct instruction *instr){
	struct avm_memcell *func = avm_translate_operand(&instr->arg1, &ax);
	assert(func);
	avm_callsaveenvironment();

	switch(func->type){
		case userfunc_m: {
			assert(0);
			break;
		}

		case string_m: avm_calllibfunc(func->data.strVal); break;
		case libfunc_m: avm_calllibfunc(func->data.libfuncVal); break;

		default: {
			assert(0);
		}
	}
}

struct avm_memcell *avm_translate_operand(struct vmarg *arg, struct avm_memcell *reg){
	switch(arg->type){
		/* variables */
		case global_a: return &stack[AVM_STACKSIZE - 1 - arg->val];
		case local_a: return &stack[topsp - arg->val];
		case formal_a: return &stack[topsp + AVM_STACKENV_SIZE + 1 + arg->val];

		case retval_a: return &retval;

		case number_a: {
			reg->type = number_m;
			reg->data.numVal = consts_getnumber(arg->val);
			return reg;
		}

		case string_a: {
			reg->type = string_m;
			reg->data.strVal = consts_getstring(arg->val);
			return reg;
		}

		case bool_a: {
			reg->type = bool_m;
			reg->data.boolVal = arg->val;
			return reg;
		}

		case nil_a: {
			reg->type = nil_m;
			return reg;
		}

		case userfunc_a: {
			reg->type = userfunc_m;
			reg->data.funcVal = arg->val;
			return reg;
		}

		case libfunc_a: {
			reg->type = libfunc_m;
			reg->data.libfuncVal = libfuncs_getused(arg->val);
			return reg;
		}

		default: {
			assert(0);
		}
	}
}

void execute_cycle(void){
	if(executionFinished)
		return;
	else if(pc == AVM_ENDING_PC){
		executionFinished = 1;
		return;
	}else{
		assert(pc < AVM_ENDING_PC);
		struct instruction *instr = code + pc;
		assert(instr->opcode >= 0 && instr->opcode <= AVM_MAX_INSTRUCTIONS);
		if(instr->srcLine)
			currLine = instr->srcLine;
		unsigned oldPC = pc;
		//printf("execute command with opcode = %d\n", instr->opcode);
		(*executeFuncs[instr->opcode])(instr);
		if(pc == oldPC)
			++pc;
	}
}

void read_binaryfile(char *filename){
  FILE *f;
  unsigned int i;
  unsigned int magicnumber = 340200501;
	size_t len;

  f = fopen(filename, "rb");
  if(f == NULL){
    perror("fopen");
    exit(1);
  }

  // read magic number
  fread(&i, sizeof(unsigned int), 1, f);
	if(i != magicnumber){
		printf("lathos magic number... avm exiting...\n");
		fclose(f);
		exit(1);
	}

	// read arrays
	// strings
	fread(&totalStringConsts, sizeof(unsigned), 1, f);
	stringConsts = malloc(totalStringConsts * sizeof(char *));
	for(i = 0; i < totalStringConsts; i++){
		fread(&len, sizeof(size_t), 1, f);
		stringConsts[i] = malloc(len * sizeof(char));
		fread(stringConsts[i], sizeof(char), len, f);
	}

	// numbers
	fread(&totalNumConsts, sizeof(unsigned), 1, f);
	numConsts = malloc(totalNumConsts * sizeof(double));
	for(i = 0; i < totalNumConsts; i++)
		fread(&numConsts[i], sizeof(double), 1, f);

	// usrfuncs
	fread(&totalUserFuncs, sizeof(unsigned), 1, f);
	if(totalUserFuncs != 0)
		assert(0);

	// libfuncs
	fread(&totalNamedLibfuncs, sizeof(unsigned), 1, f);
	namedLibfuncs = malloc(totalNamedLibfuncs * sizeof(char *));
	for(i = 0; i < totalNamedLibfuncs; i++){
		fread(&len, sizeof(size_t), 1, f);
		namedLibfuncs[i] = malloc(len * sizeof(char));
		fread(namedLibfuncs[i], sizeof(char), len, f);
	}

	// read instructions
	fread(&codeSize, sizeof(unsigned int), 1, f);
	printf("number of instructions = %u\n", codeSize);
	code = malloc(codeSize * sizeof(struct instruction));
	for(i = 0; i < codeSize; i++){
    fread(&code[i].opcode, sizeof(enum vmopcode), 1, f);

    fread(&code[i].result.type, sizeof(enum vmarg_t), 1, f);
    fread(&code[i].result.val, sizeof(unsigned), 1, f);

    fread(&code[i].arg1.type, sizeof(enum vmarg_t), 1, f);
    fread(&code[i].arg1.val, sizeof(unsigned), 1, f);

    fread(&code[i].arg2.type, sizeof(enum vmarg_t), 1, f);
    fread(&code[i].arg2.val, sizeof(unsigned), 1, f);
	}

	fclose(f);
}

int main(int argc, char **argv){
	char *filename;

//	printf("avm started...\n");

	if(argc != 2){
		printf("dwste to binary file!\n");
		exit(1);
	}

	filename = argv[1];

	read_binaryfile(filename);

	avm_initstack();

	printf("-----------------------\n");
	while(!executionFinished)
		execute_cycle();

	return 0;
}
