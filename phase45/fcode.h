#ifndef _FCODE_H_
#define _FCODE_H_

enum vmopcode {
	assign_v, add_v, sub_v,
	mul_v, div_v, mod_v,
	uminus_v, and_v, or_v,
	not_v, jmp_v, jeq_v, jne_v,
	jle_v, jge_v, jlt_v,
	jgt_v, call_v, pusharg_v,
	funcenter_v, funcexit_v, newtable_v,
	tablegetelem_v, tablesetelem_v, nop_v
};

enum vmarg_t {
	label_a = 0,
	global_a = 1,
	formal_a = 2,
	local_a = 3,
	number_a = 4,
	string_a = 5,
	bool_a = 6,
	nil_a = 7,
	userfunc_a = 8,
	libfunc_a = 9,
	retval_a = 10
};

struct vmarg {
	enum vmarg_t type;
	unsigned val;
};

struct instruction {
	enum vmopcode opcode;
	struct vmarg result; 
	struct vmarg arg1;
	struct vmarg arg2;
	unsigned srcLine;
};

struct userfunc {
	unsigned address;
	unsigned localsize;
	char *id;
};

struct incomplete_jump {
	unsigned instrNo;
	unsigned iaddress;
	struct incomplete_jump *next;
};

void generate_ADD(struct quad *q);
void generate_SUB(struct quad *q);
void generate_MUL(struct quad *q);
void generate_DIV(struct quad *q);
void generate_MOD(struct quad *q);
void generate_UMINUS(struct quad *q);
void generate_NEWTABLE(struct quad *q);
void generate_TABLESETEMEM(struct quad *q);
void generate_TABLEGETELEM(struct quad *q);
void generate_ASSIGN(struct quad *q);
void generate_NOP(struct quad *q);
void generate_JUMP(struct quad *q);
void generate_IF_EQ(struct quad *q);
void generate_IF_NEQ(struct quad *q);
void generate_IF_GREATER(struct quad *q);
void generate_IF_GREATEREQ(struct quad *q);
void generate_IF_LESS(struct quad *q);
void generate_IF_LESSEQ(struct quad *q);
void generate_NOT(struct quad *q);
void generate_OR(struct quad *q);
void generate_AND(struct quad *q);
void generate_PARAM(struct quad *q);
void generate_CALL(struct quad *q);
void generate_GETRETVAL(struct quad *q);
void generate_FUNCSTART(struct quad *q);
void generate_FUNCEND(struct quad *q);
void generate_RETURN(struct quad *q);

void patch_incomplete_jumps(void);
void generate_instructions(void);
void create_binaryfile(char *filename);

#endif
