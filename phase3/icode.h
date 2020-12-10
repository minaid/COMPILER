#ifndef _ICODE_H_
#define _ICODE_H_

#include "shared.h"
#include "symbol_table.h"

// front 4 slide 13
enum iopcode {
	assign, add, sub,
	mul, divi, mod,
	uminus, and, or, not,
	if_eq, if_noteq, if_lesseq,
	if_greatereq, if_less, if_greater,
	call, param, ret, getretval,
	funcstart, funcend,
	tablecreate, tablegetelem, tablesetelem,
	jump // den to eixe stis dialekseis...
};

// front 4 slide 15
enum expr_t {
	var_e,
	tableitem_e,

	programfunc_e,
	libraryfunc_e,

	arithexpr_e,
	boolexpr_e,
	assignexpr_e,
	newtable_e,

	constnum_e,
	constbool_e,
	conststring_e,

	nil_e
};

struct expr {
	enum expr_t type;
	struct SymbolTableEntry *sym;
	struct expr *index;
	double numConst;
	char *strConst;
	unsigned char boolConst;
	struct expr *next;
};

struct quad {
	enum iopcode op;
	struct expr *result;
	struct expr *arg1;
	struct expr *arg2;
	unsigned int label;
	unsigned int line;
};

extern unsigned int functionLocalOffset;

// prototypes
enum scopespace_t currscopespace(void);
unsigned int currscopeoffset(void);
void inccurrscopeoffset(void);
void enterscopespace(void);
void exitscopespace(void);
void resetformalargsoffset(void);
void resetfunctionlocalsoffset(void);

struct expr *lvalue_expr(struct SymbolTableEntry *sym);
struct expr *emit_iftableitem(struct expr *e);
struct expr *member_item(struct expr *lvalue, char *name);
struct expr *make_call(struct expr *lvalue, struct expr *elist);

struct SymbolTableEntry *newtemp(void);
struct expr *newexpr_conststring(char *s);
struct expr *newexpr_constbool(unsigned char b);
struct expr *newexpr_constnum(double b);
struct expr *newexpr(enum expr_t t);

void patchlabel(unsigned int i, unsigned int l);
unsigned int nextquad(void);
void emit(enum iopcode op, struct expr *arg1, struct expr *arg2, struct expr *result, unsigned int label, unsigned int line);
void print_quads(void);

#endif
