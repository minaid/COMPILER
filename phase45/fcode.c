#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "icode.h"
#include "fcode.h"

#define FEXPAND_SIZE 1024
#define FCURR_SIZE (ftotal * sizeof(struct instruction))
#define FNEW_SIZE (FEXPAND_SIZE * sizeof(struct instruction) + FCURR_SIZE)

typedef void (*generator_func_t)(struct quad *);

/* einai me thn idia seira pou einai kai sto struct iopcode sto icode.h */
generator_func_t generators[] = {
	generate_ASSIGN,
	generate_ADD,
	generate_SUB,
	generate_MUL,
	generate_DIV,
	generate_MOD,
	generate_UMINUS,
	generate_AND,
	generate_OR,
	generate_NOT,
	generate_IF_EQ,
	generate_IF_NEQ,
	generate_IF_LESSEQ,
	generate_IF_GREATEREQ,
	generate_IF_LESS,
	generate_IF_GREATER,
	generate_CALL,
	generate_PARAM,
	generate_RETURN,
	generate_GETRETVAL,
	generate_FUNCSTART,
	generate_FUNCEND,
	generate_NEWTABLE,
	generate_TABLESETEMEM,
	generate_TABLEGETELEM,
	generate_JUMP,
	generate_NOP
};

struct instruction *instructions = NULL;
unsigned int ftotal = 0;
unsigned int currInstr = 0;
unsigned int currProcessedQuad = 0;

double *numConsts = NULL;
unsigned totalNumConsts = 0;
char **stringConsts;
unsigned totalStringConsts = 0;
char **namedLibfuncs = NULL;
unsigned totalNamedLibfuncs = 0;
struct userfunc *userFuncs;
unsigned totalUserFuncs = 0;

struct incomplete_jump *ij_head = NULL;
unsigned ij_total = 0;

unsigned int nextinstructionlabel(void){ return currInstr; }

void fexpand(void){
	assert(ftotal == currInstr);
	struct instruction *i = (struct instruction *)malloc(FNEW_SIZE);
	if(instructions){
		memcpy(i, instructions, FCURR_SIZE);
		free(instructions);
	}
	instructions = i;
	ftotal += FEXPAND_SIZE;
}

void femit(struct instruction t){
	if(currInstr == ftotal)
		fexpand();

	struct instruction *i = instructions + currInstr++;
	i->opcode = t.opcode;
	i->result = t.result;
	i->arg1 = t.arg1;
	i->arg2 = t.arg2;
	i->srcLine = 0; // ??
}

void generate_instructions(void){
	for(currProcessedQuad = 0; currProcessedQuad < currQuad; ++currProcessedQuad){
	//	printf("generate %u : op = %u\n", currProcessedQuad, quads[currProcessedQuad].op);
		(*generators[quads[currProcessedQuad].op])(quads + currProcessedQuad);
	}

	patch_incomplete_jumps();
}

unsigned consts_newstring(char *s){
	if(stringConsts == NULL)
		stringConsts = malloc(4096 * sizeof(char *));

	stringConsts[totalStringConsts] = strdup(s);
	totalStringConsts++;

	return totalStringConsts - 1;
}

unsigned consts_newnumber(double n){
	if(numConsts == NULL)
		numConsts = malloc(4096 * sizeof(double));

	numConsts[totalNumConsts] = n;
	totalNumConsts++;

	return totalNumConsts - 1;
}

unsigned libfuncs_newused(char *s){
	if(namedLibfuncs == NULL)
		namedLibfuncs = malloc(4096 * sizeof(char *));

	namedLibfuncs[totalNamedLibfuncs] = strdup(s);
	totalNamedLibfuncs++;

	return totalNamedLibfuncs - 1;
}

unsigned userfuncs_newfunc(struct SymbolTableEntry *sym){
	assert(0);
}

void make_operand(struct expr *e, struct vmarg *arg){
	if(e == NULL) 
		return;

	switch(e->type){
		/* all those below use a variable for storage */
		case var_e:
		case tableitem_e:
		case arithexpr_e:
		case assignexpr_e:
		case boolexpr_e:
		case newtable_e: {
			assert(e->sym);
			arg->val = e->sym->offset;
			switch(e->sym->space){
				case programvar: arg->type = global_a; break;
				case functionlocal: arg->type = local_a; break;
				case formalarg: arg->type = formal_a; break;
				default: assert(0);
			}
			break; /* from case newtable_e */
		}

		/* constants */
		case constbool_e: {
			arg->val = e->boolConst;
			arg->type = bool_a;
			break;
		}

		case conststring_e: {
			arg->val = consts_newstring(e->strConst);
			arg->type = string_a;
			break;
		}

		case constnum_e: {
			arg->val = consts_newnumber(e->numConst);
			arg->type = number_a;
			break;
		}

		case nil_e: {
			arg->type = nil_a;
			break;
		}

		/* functions */
		case programfunc_e: {
			arg->type = userfunc_a;
			arg->val = e->sym->taddress;
			/* or alternative */
			arg->val = userfuncs_newfunc(e->sym);
			break;
		}

		case libraryfunc_e: {
			arg->type = libfunc_a;
			arg->val = libfuncs_newused(e->sym->name);
			break;
		}

		default: {
			printf("expr type = %d\n", e->type);
			assert(0);
		}
	}
}

void make_numberoperand(struct vmarg *arg, double val){
	arg->val = consts_newnumber(val);
	arg->type = number_a;
}

void make_booloperand(struct vmarg *arg, unsigned val){
	arg->val = val;
	arg->type = bool_a;
}

void make_retvaloperand(struct vmarg *arg){
	arg->type = retval_a;
}

void reset_operand(struct vmarg *arg){
	arg->type = 0;
	arg->val = 0;
}

void add_incomple_jump(unsigned instrNo, unsigned iaddress){
	struct incomplete_jump *tmp = malloc(sizeof(struct incomplete_jump));
	tmp->instrNo = instrNo;
	tmp->iaddress = iaddress;
	tmp->next = ij_head;
	ij_head = tmp;
	ij_total++;
}

/* lecture 14 slide 15 */
void patch_incomplete_jumps(void){
	struct incomplete_jump *tmp;

	for(tmp = ij_head; tmp != NULL; tmp = tmp->next){
		if(tmp->iaddress == currQuad)
			instructions[tmp->instrNo].result.val = currInstr;
		else
			instructions[tmp->instrNo].result.val = quads[tmp->iaddress].taddress;
	}
}

void generate(enum vmopcode op, struct quad *q){
	struct instruction t;
	t.opcode = op;
	make_operand(q->arg1, &t.arg1);
	make_operand(q->arg2, &t.arg2);
	make_operand(q->result, &t.result);
	q->taddress = nextinstructionlabel();
	femit(t);
}

void generate_ADD(struct quad *q){ generate(add_v, q); }
void generate_SUB(struct quad *q){ generate(sub_v, q); }
void generate_MUL(struct quad *q){ generate(mul_v, q); }
void generate_DIV(struct quad *q){ generate(div_v, q); }
void generate_MOD(struct quad *q){ generate(mod_v, q); }

void generate_NEWTABLE(struct quad *q) { generate(newtable_v, q); }
void generate_TABLESETEMEM(struct quad *q) { generate(tablesetelem_v, q); }
void generate_TABLEGETELEM(struct quad *q) { generate(tablegetelem_v, q); }
void generate_ASSIGN(struct quad *q) { generate(assign_v, q); }
void generate_NOP(struct quad *q) { struct instruction t; t.opcode = nop_v; femit(t); }

unsigned int currprocessedquad(void){ return currProcessedQuad; }

void generate_relational(enum vmopcode op, struct quad *q){
	struct instruction t;
	t.opcode = op;
	make_operand(q->arg1, &t.arg1);
	make_operand(q->arg2, &t.arg2);

	t.result.type = label_a;
	if(q->label < currprocessedquad())
		t.result.val = quads[q->label].taddress;
	else
		add_incomple_jump(nextinstructionlabel(), q->label);

	q->taddress = nextinstructionlabel();
	femit(t);
}

void generate_JUMP(struct quad *q){ generate_relational(jmp_v, q); }
void generate_IF_EQ(struct quad *q){ generate_relational(jeq_v, q); }
void generate_IF_NEQ(struct quad *q){ generate_relational(jne_v, q); }
void generate_IF_GREATER(struct quad *q){ generate_relational(jgt_v, q); }
void generate_IF_GREATEREQ(struct quad *q){ generate_relational(jge_v, q); }
void generate_IF_LESS(struct quad *q){ generate_relational(jlt_v, q); }
void generate_IF_LESSEQ(struct quad *q){ generate_relational(jle_v, q); }

void generate_NOT(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;

	t.opcode = jeq_v;
	make_operand(q->arg1, &t.arg1);
	make_booloperand(&t.arg2, 0);
	t.result.type = label_a;
	t.result.val = nextinstructionlabel() + 3;
	femit(t);

	t.opcode = assign_v;
	make_booloperand(&t.arg1, 0);
	reset_operand(&t.arg2);
	make_operand(q->result, &t.result);
	femit(t);

	t.opcode = jmp_v;
	reset_operand(&t.arg1);
	reset_operand(&t.arg2);
	t.result.type = label_a;
	t.result.val = nextinstructionlabel() + 2;
	femit(t);

	t.opcode = assign_v;
	make_booloperand(&t.arg1, 1);
	reset_operand(&t.arg2);
	make_operand(q->result, &t.result);
	femit(t);
}

void generate_OR(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;

	t.opcode = jeq_v;
  make_operand(q->arg1, &t.arg1);
  make_booloperand(&t.arg2, 1);
  t.result.type = label_a;
  t.result.val = nextinstructionlabel() + 4;
  femit(t);

	make_operand(q->arg2, &t.arg1);
	t.result.val = nextinstructionlabel() + 3;
	femit(t);

	t.opcode = assign_v;
  make_booloperand(&t.arg1, 0);
  reset_operand(&t.arg2);
  make_operand(q->result, &t.result);
  femit(t);

	t.opcode = jmp_v;
  reset_operand(&t.arg1);
  reset_operand(&t.arg2);
  t.result.type = label_a;
  t.result.val = nextinstructionlabel() + 2;
  femit(t);

	t.opcode = assign_v;
  make_booloperand(&t.arg1, 1);
  reset_operand(&t.arg2);
  make_operand(q->result, &t.result);
  femit(t);
}

void generate_AND(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;

	t.opcode = jeq_v;
  make_operand(q->arg1, &t.arg1);
  make_booloperand(&t.arg2, 0);
  t.result.type = label_a;
  t.result.val = nextinstructionlabel() + 4;
  femit(t);

	make_operand(q->arg2, &t.arg1);
	t.result.val = nextinstructionlabel() + 3;
	femit(t);

	t.opcode = assign_v;
  make_booloperand(&t.arg1, 1);
  reset_operand(&t.arg2);
  make_operand(q->result, &t.result);
  femit(t);

	t.opcode = jmp_v;
  reset_operand(&t.arg1);
  reset_operand(&t.arg2);
  t.result.type = label_a;
  t.result.val = nextinstructionlabel() + 2;
  femit(t);

	t.opcode = assign_v;
  make_booloperand(&t.arg1, 0);
  reset_operand(&t.arg2);
  make_operand(q->result, &t.result);
  femit(t);
}

void generate_PARAM(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;
	t.opcode = pusharg_v;
	make_operand(q->result, &t.arg1);
	femit(t);
}

void generate_CALL(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;
	t.opcode = call_v;
	make_operand(q->result, &t.arg1);
	femit(t);
}

void generate_GETRETVAL(struct quad *q){
	q->taddress = nextinstructionlabel();
	struct instruction t;
	t.opcode = assign_v;
	make_operand(q->result, &t.result);
	make_retvaloperand(&t.arg1);
	femit(t);
}

void generate_FUNCSTART(struct quad *q){
	assert(0);
}

void generate_FUNCEND(struct quad *q){
	assert(0);
}

void generate_RETURN(struct quad *q){
	assert(0);
}

void generate_UMINUS(struct quad *q){
	struct instruction t;
	t.opcode = mul_v;
	make_operand(q->arg1, &t.arg1);
	make_numberoperand(&t.arg2, -1.0);
	make_operand(q->result, &t.result);
	q->taddress = nextinstructionlabel();
	femit(t);
}

void create_binaryfile(char *filename){
	FILE *f;
	unsigned int i;
	unsigned int magicnumber = 340200501;

	f = fopen(filename, "wb");
	if(f == NULL){
		perror("fopen");
		exit(1);
	}

	// write magic number
	fwrite(&magicnumber, sizeof(unsigned int), 1, f);

	// write arrays
	// strings
	fwrite(&totalStringConsts, sizeof(unsigned), 1, f);
	for(i = 0; i < totalStringConsts; i++){
		size_t len = strlen(stringConsts[i]) + 1;
		fwrite(&len, sizeof(size_t), 1, f);
		fwrite(stringConsts[i], sizeof(char), len, f); // + '\0'
	}

	// numbers
	fwrite(&totalNumConsts, sizeof(unsigned), 1, f);
	fwrite(numConsts, sizeof(double), totalNumConsts, f);

	// usrfuncs
	fwrite(&totalUserFuncs, sizeof(unsigned), 1, f);
	if(totalUserFuncs != 0)
		assert(0);

	// libfuncs
	fwrite(&totalNamedLibfuncs, sizeof(unsigned), 1, f);
	for(i = 0; i < totalNamedLibfuncs; i++){
		size_t len = strlen(namedLibfuncs[i]) + 1;
		fwrite(&len, sizeof(size_t), 1, f);
		fwrite(namedLibfuncs[i], sizeof(char), len, f); // + '\0'
	}

	// write code
	printf("number of instructions = %u\n", currInstr);
	fwrite(&currInstr, sizeof(unsigned int), 1, f);
	for(i = 0; i < currInstr; i++){
		fwrite(&instructions[i].opcode, sizeof(enum vmopcode), 1, f);

		fwrite(&instructions[i].result.type, sizeof(enum vmarg_t), 1, f);
		fwrite(&instructions[i].result.val, sizeof(unsigned), 1, f);

		fwrite(&instructions[i].arg1.type, sizeof(enum vmarg_t), 1, f);
		fwrite(&instructions[i].arg1.val, sizeof(unsigned), 1, f);

		fwrite(&instructions[i].arg2.type, sizeof(enum vmarg_t), 1, f);
		fwrite(&instructions[i].arg2.val, sizeof(unsigned), 1, f);
	}

	fclose(f);
}
