#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "icode.h"

extern int yylineno;
unsigned int scope;

// lecture 9 slide 45
int tempcounter = 0;  

const char *iopcode_str[] = { "ASSIGN", "ADD", "SUB", "MUL", "DIV", "MOD", "UMINUS", "AND", "OR", "NOT", "IF_EQ", "IF_NOTEQ", "IF_LESSEQ", "IF_GREATEREQ", "IF_LESS", "IF_GREATER", "CALL",
"PARAM", "RETURN", "GETRETVAL", "FUNCSTART", "FUNCEND", "TABLECREATE", "TABLEGETELEM", "TABLESETELEM", "JUMP" };

// lecture 9 slide 37
struct quad *quads = NULL;
unsigned int total = 0;
unsigned int currQuad = 0;

#define EXPAND_SIZE 1024
#define CURR_SIZE (total * sizeof(struct quad))
#define NEW_SIZE (EXPAND_SIZE * sizeof(struct quad) + CURR_SIZE)

// lecture 9 slide 49
unsigned int programVarOffset = 0;
unsigned int functionLocalOffset = 0;
unsigned int formalArgOffset = 0;
unsigned int scopeSpaceCounter = 1;

void patchlabel(unsigned int i, unsigned int l)
{
	quads[i].label = l;
}

// lecture 9 slide 38
void expand(void)
{
	assert(total == currQuad);
	struct quad *p = (struct quad *)malloc(NEW_SIZE);
	if(quads){
		memcpy(p, quads, CURR_SIZE);
		free(quads);
	}
	quads = p;
	total += EXPAND_SIZE;
}

void emit(enum iopcode op, struct expr *arg1, struct expr *arg2, struct expr *result, unsigned int label, unsigned int line)
{
	if(currQuad == total)
		expand();

	struct quad *p = quads + currQuad++;
	p->op = op; // den to exei sthn dialeksi
	p->arg1 = arg1;
	p->arg2 = arg2;
	p->result = result;
	p->label = label;
	p->line = line;
}

void print_expr(struct expr *e)
{
	if(e != NULL){
		switch(e->type){
				case var_e:
				case arithexpr_e:
				case assignexpr_e:
				case boolexpr_e:
				case tableitem_e:
				case programfunc_e:
				case newtable_e:
				case libraryfunc_e:
					printf("%s ", e->sym->name);
					break;
				case constnum_e:
					printf("%lf ", e->numConst);
					break;
				case constbool_e:
					printf("%s ", (e->boolConst == 1)?("TRUE"):("FALSE"));
					break;
				case conststring_e:
					printf("\"%s\" ", e->strConst);
					break;
				case nil_e:
					printf("nil ");
					break;
				default:
					printf("type == %d\n", e->type);
					assert(0);
			}
		}
}

void print_quads(void)
{
	int i;

	for(i = 0; i < currQuad; ++i){
		printf("%3d : %s ", i, iopcode_str[quads[i].op]);
		print_expr(quads[i].arg1);
		print_expr(quads[i].arg2);
		if(quads[i].op == jump || quads[i].op == if_greatereq || quads[i].op == if_greater || quads[i].op == if_less || quads[i].op == if_lesseq || quads[i].op == if_eq || quads[i].op == if_noteq){
			printf("%u ", quads[i].label);
		}else{
			print_expr(quads[i].result);
		}
		printf("\n");
	}
}

// lecture 9 slide 45
char *newtempname(void)
{
	char n[200];
	sprintf(n, "_t%d", tempcounter++); // den thelei ++? den to exei stis dialekseis
	return strdup(n);
}

void resettemp(void)
{
	tempcounter = 0;
}

unsigned int currscope(void)
{
	return scope;
}

struct SymbolTableEntry *newtemp(void)
{
	char *name = newtempname();
	struct SymbolTableEntry *sym = symbol_table_lookup(name, currscope());
	if(sym == NULL){
		Variable *v = malloc(sizeof(Variable));
	  v->name = name;
		v->scope = currscope();
		v->line = yylineno;
		return symbol_table_insert(v, (currscope() == 0)?(GLOBAL):(LOCALL));
	}else{
		return sym;
	}
}

// lecture 9 slide 49
enum scopespace_t currscopespace(void)
{
	if(scopeSpaceCounter == 1)
		return programvar;
	else if(scopeSpaceCounter % 2 == 0)
		return formalarg;
	else
		return functionlocal;
}

// lecture 9 slide 50
unsigned int currscopeoffset(void)
{
	switch(currscopespace()){
		case programvar: return programVarOffset;
		case functionlocal: return functionLocalOffset;
		case formalarg: return formalArgOffset;
		default: assert(0);
	}
}

void inccurrscopeoffset(void)
{
	switch(currscopespace()){
		case programvar: ++programVarOffset; break;
		case functionlocal: ++functionLocalOffset; break;
		case formalarg: ++formalArgOffset; break;
		default: assert(0);
	}
}

void enterscopespace(void)
{
	++scopeSpaceCounter;
}

void exitscopespace(void)
{
	assert(scopeSpaceCounter > 1);
	--scopeSpaceCounter;
}

// lecture 10 slide 10
void resetformalargsoffset(void)
{
	formalArgOffset = 0;
}

void resetfunctionlocalsoffset(void)
{
	functionLocalOffset = 0;
}

void restorecurrscopeoffset(unsigned int n)
{
	switch(currscopespace()){
		case programvar: programVarOffset = n; break;
		case functionlocal: functionLocalOffset = n; break;
		case formalarg: formalArgOffset = n; break;
		default: assert(0);
	}
}

// lecture 10 slide 18
struct expr *lvalue_expr(struct SymbolTableEntry *sym)
{
	assert(sym);
	struct expr *e = (struct expr *)malloc(sizeof(struct expr));
	memset(e, 0, sizeof(struct expr));

	e->next = NULL;
	e->sym = sym;

	switch(sym->typ){
		case var_s: e->type = var_e; break;
		case programfunc_s: e->type = programfunc_e; break;
		case libraryfunc_s: e->type = libraryfunc_e; break;
		default: assert(0);
	}
	
	return e;
}

// lecture 10 slide 21
struct expr *member_item(struct expr *lvalue, char *name)
{
	lvalue = emit_iftableitem(lvalue);
	struct expr *item = newexpr(tableitem_e);
	item->sym = lvalue->sym;
	item->index = newexpr_conststring(name);
	return item;
}

// lecture 10 slide 24
struct expr *newexpr(enum expr_t t)
{
	struct expr *e = (struct expr *)malloc(sizeof(struct expr));
	memset(e, 0, sizeof(struct expr));
	e->type = t;
	return e;
}

struct expr *newexpr_conststring(char *s)
{
	struct expr *e = newexpr(conststring_e);
	e->strConst = strdup(s);
	return e;
}

struct expr *newexpr_constbool(unsigned char b)
{
	struct expr *e = newexpr(constbool_e);
	e->boolConst = b;
	return e;
}

struct expr *newexpr_constnum(double b)
{
	struct expr *e = newexpr(constnum_e);
	e->numConst = b;
	return e;
}

struct expr *emit_iftableitem(struct expr *e)
{
	if(e->type != tableitem_e){
		return e;
	}else{
		struct expr *result = newexpr(var_e);
		result->sym = newtemp();
		emit(tablegetelem, e, e->index, result, 0, yylineno);
		return result;
	}
}

unsigned int nextquad(void)
{
	return currQuad;
}

// lecture 10 - slide 27
struct expr *make_call(struct expr *lvalue, struct expr *elist)
{
	struct expr *tmp;
	struct expr *nlist = NULL;
	struct expr *t;
	struct expr *result;
	struct expr *func = emit_iftableitem(lvalue);

	// antistrefoume thn lista
	tmp = elist;
	while(tmp != NULL){
		t = tmp;
		tmp = tmp->next;
		t->next = nlist;
		nlist = t;
	}

	for(tmp = nlist; tmp != NULL; tmp = tmp->next)
		emit(param, NULL, NULL, tmp, 0, yylineno);
	
	emit(call, NULL, NULL, func, 0, yylineno);
	result = newexpr(var_e);
	result->sym = newtemp();
	emit(getretval, NULL, NULL, result, 0, yylineno);
	return result;
}
