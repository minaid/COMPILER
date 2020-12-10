%{
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>

#include "symbol_table.h"
#include "fcode.h"

int yyerror(char *yaccProvidedMessage);
int yylex(void);

extern int yylineno;
extern char *yytext;
extern FILE *yyin;

unsigned int scope = 0;
unsigned int no_name_userfunc_num = 0;
char no_name_userfunc_str[100];
unsigned int loop_counter = 0; // metrame ama eimaste se loop 
unsigned int function_counter = 0; // metrame ama eimaste se synarthsh

#define NUM_LIBFUNCS 12
const char *libfunc[] = {"print", "input", "objectmemberkeys", "objecttotalmembers", "objectcopy", "totalarguments", "argument", "typeof", "strtonum", "sqrt", "cos", "sin"};

struct methodcall {
	struct expr *elist;
	unsigned char method;
	char *name;
};

struct forpref {
	unsigned int test;
	unsigned int enter;
};

struct stack_node {
	unsigned int val;
	struct stack_node *next;
};

struct stack {
	struct stack_node *head;
};

struct stack *functionLocalsStack = NULL;

struct stack *new_stack(){
	struct stack *tmp = malloc(sizeof(struct stack));
	tmp->head = NULL;
	return tmp;
}

void push(struct stack *s, unsigned int v){
	struct stack_node *tmp = malloc(sizeof(struct stack_node));
	tmp->val = v;
	tmp->next = s->head;
	s->head = tmp;
}

unsigned int pop(struct stack *s){
	if(s->head == NULL){
		assert(0);
		return 0;
	}else{
		unsigned int ret = s->head->val;
		s->head = s->head->next;
		return ret;
	}
}

int is_libfunc(const char *s)
{
	int i;

	for(i = 0; i < NUM_LIBFUNCS; i++)
		if(strcmp(libfunc[i], s) == 0)
			return 1;

	return 0;
}

char *get_userfunc_name(void)
{
	sprintf(no_name_userfunc_str, "$f%u", no_name_userfunc_num);
	++no_name_userfunc_num;
	return no_name_userfunc_str;
}

int is_expr_valid_arithop(struct expr *e)
{
	if(e->type == programfunc_e || e->type == libraryfunc_e || e->type == boolexpr_e || 
		 e->type == newtable_e || e->type == constbool_e || e->type == conststring_e || 
		 e->type == nil_e)
		return 0;
	else
		return 1;
}

struct expr *arithop(enum iopcode op, struct expr *e1, struct expr *e2)
{
	struct expr *e;

	// lecture 11 slide 5
	if(e1->type == constnum_e && e2->type == constnum_e){
		e = newexpr(constnum_e);
		if(op == add)
			e->numConst = e1->numConst + e2->numConst;
		else if(op == sub)
			e->numConst = e1->numConst - e2->numConst;
		else if(op == mul)
			e->numConst = e1->numConst * e2->numConst;
		else if(op == divi)
			e->numConst = e1->numConst / e2->numConst;
		else if(op == mod)
			e->numConst = (int)e1->numConst % (int)e2->numConst;
		else
			assert(0);
	}else if(is_expr_valid_arithop(e1) && is_expr_valid_arithop(e2)){
		e = newexpr(arithexpr_e);
		e->sym = newtemp();
		emit(op, e1, e2, e, 0, yylineno);
	}else{
		printf("ERROR: not valid type in arithop at line %u\n", yylineno);
		exit(1);
	}

	return e;
}

// leipoun elegxoi
struct expr *relop(enum iopcode op, struct expr *e1, struct expr *e2)
{
	struct expr *e;

	// lecture 11 slide 6
	e = newexpr(boolexpr_e);
	e->sym = newtemp();

	emit(op, e1, e2, NULL, nextquad() + 3, yylineno);
	emit(assign, newexpr_constbool(0), NULL, e, 0, yylineno);
	emit(jump, NULL, NULL, NULL, nextquad() + 2, yylineno);
	emit(assign, newexpr_constbool(1), NULL, e, 0, yylineno);

	return e;
}

%}

%start program

%union {
	char *str; /* idio gia string kai ident */
	int intconst;
	double realconst;
	struct expr *sval;
	struct SymbolTableEntry *symbol;
	struct methodcall *mcall;
	struct forpref *fpre;
}

%token <str> IDENT
%token <str> STRING
%token <intconst> INTCONST
%token <realconst> REALCONST

%type <intconst> ifprefix elseprefix whilestart whilecond forN forM
%type <fpre> forprefix

%type <str> funcname
%type <intconst> funcbody
%type <symbol> funcprefix funcdef

%type <sval> const primary lvalue term expr assignexpr member elist call objectdef indexedelem indexed

%type <mcall> methodcall normcall callsuffix

%token IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE LOCAL TRUE FALSE NIL LBRACKET RBRACKET SEMICOLON COMMA COLON DCOLON

%right ASSIGN
%left OR
%left AND
%nonassoc EQ NEQ
%nonassoc GT LT GEQ LEQ
%left ADD SUB
%left MUL DIV MOD
%right NOT INCR DECR UMINUS
%left DOT DDOT
%left LBRACE RBRACE
%left LPARETH RPARETH
%right THEN ELSE

%%

program:	stmts { printf("program: stmts\n"); }
					| /* empty */ { printf("program: empty\n"); }
					;

stmts:	stmts stmt { printf("stmts: stmts stmt\n"); }
				| stmt { printf("stmts: stmt\n"); }
				;

stmt: expr SEMICOLON { printf("stmt: expr SEMICOLON\n"); }
			| ifstmt { printf("stmt: ifstmt\n"); }
			| whilestmt { printf("stmt: whilestmt\n"); }
			| forstmt { printf("stmt: forstmt\n"); }
			| returnstmt { printf("stmt: returnstmt\n"); }
			| BREAK SEMICOLON { 
				if(loop_counter < 1){
					printf("ERROR: cannot have a break outside a loop at line %u\n", yylineno);
					exit(1);
				}
				printf("stmt: BREAK SEMICOLON\n"); 
			}
			| CONTINUE SEMICOLON { 
				if(loop_counter < 1){
					printf("ERROR: cannot have a continue outside a loop at line %u\n", yylineno);
					exit(1);
				}
				printf("stmt: CONTINUE SEMICOLON\n"); 
			}
			| { ++scope; } block  { symbol_table_hide(scope--); printf("stmt: block\n"); }
			| funcdef { printf("stmt: funcdef\n"); }
			| SEMICOLON { printf("stmt: SEMICOLON\n"); }
			;

expr:	assignexpr { 
				printf("expr: assignexpr\n"); 
				$$ = $1;	
			}
			| expr ADD expr { 
				printf("expr: expr ADD expr\n");
				$$ = arithop(add, $1, $3);
			}
			| expr SUB expr { 
				printf("expr: expr SUB expr\n"); 
				$$ = arithop(sub, $1, $3);
			}
			| expr MUL expr { 
				printf("expr: expr MUL expr\n"); 
				$$ = arithop(mul, $1, $3);
			}
			| expr DIV expr { 
				printf("expr: expr DIV expr\n"); 
				$$ = arithop(divi, $1, $3);
			}
			| expr MOD expr { 
				printf("expr: expr MOD expr\n"); 
				$$ = arithop(mod, $1, $3);
			}
			| expr GT expr { 
				printf("expr: expr GT expr\n"); 
				$$ = relop(if_greater, $1, $3);
			}
			| expr GEQ expr { 
				printf("expr: expr GEQ expr\n"); 
				$$ = relop(if_greatereq, $1, $3);
			}
			| expr LT expr { 
				printf("expr: expr LT expr\n"); 
				$$ = relop(if_less, $1, $3);
			}
			| expr LEQ expr { 
				printf("expr: expr LEQ expr\n"); 
				$$ = relop(if_lesseq, $1, $3);
			}
			| expr EQ expr { 
				printf("expr: expr EQ expr\n"); 
				$$ = relop(if_eq, $1, $3);
			}
			| expr NEQ expr { 
				printf("expr: expr NEQ expr\n"); 
				$$ = relop(if_noteq, $1, $3);
			}
			| expr AND expr { 
				printf("expr: expr AND expr\n"); 
				$$ = newexpr(boolexpr_e);
				$$->sym = newtemp();
				emit(and, $1, $3, $$, 0, yylineno);
			}
			| expr OR expr { 
				printf("expr: expr OR expr\n"); 
				$$ = newexpr(boolexpr_e);
				$$->sym = newtemp();
				emit(or, $1, $3, $$, 0, yylineno);
			}
			| term { 
				printf("expr: term\n"); 
				$$ = $1;
			}
			;

term:	LPARETH expr RPARETH { 
				printf("term: LPARETH expr RPARETH\n"); 
				$$ = $2;
			}
			| SUB expr %prec UMINUS { 
				printf("term: SUB expr\n"); 
				// lecture 10 slide 32
				if(	$2->type == constbool_e ||
						$2->type == conststring_e ||
						$2->type == nil_e ||
						$2->type == newtable_e ||
						$2->type == programfunc_e ||
						$2->type == libraryfunc_e ||
						$2->type == boolexpr_e)
				{
					printf("ERROR: Illegal expr to unary - at line %u\n", yylineno);
					exit(1);
				}

				$$ = newexpr(arithexpr_e);
				$$->sym = newtemp();
				emit(uminus, $2, NULL, $$, 0, yylineno);
			}
			| NOT expr { 
				printf("term: NOT expr\n"); 
				// lecture 10 slide 32
				$$ = newexpr(boolexpr_e);
				$$->sym = newtemp();
				emit(not, $2, NULL, $$, 0, yylineno);
			}
			| INCR lvalue { 
				printf("term: INCR lvalue\n");
				// lecture 10 slide 34
				if($2->type == tableitem_e){
					$$ = emit_iftableitem($2);
					emit(add, $$, newexpr_constnum(1), $$, 0, yylineno);
					emit(tablesetelem, $2, $2->index, $$, 0, yylineno);
				}else{
					emit(add, $2, newexpr_constnum(1), $2, 0, yylineno);
					$$ = newexpr(arithexpr_e);
					$$->sym = newtemp();
					emit(assign, $2, NULL, $$, 0, yylineno);
				}
			}
			| lvalue INCR { 
				printf("term: lvalue INCR\n"); 
				// lecture 10 slide 33
				$$ = newexpr(var_e);
				$$->sym = newtemp();

				if($1->type == tableitem_e){
					struct expr *value = emit_iftableitem($1);
					emit(assign, $1, NULL, $$, 0, yylineno);
					emit(add, value, newexpr_constnum(1), value, 0, yylineno);
					emit(tablesetelem, $1, $1->index, value, 0, yylineno);
				}else{
					emit(assign, $1, NULL, $$, 0, yylineno);
					emit(add, $1, newexpr_constnum(1), $1, 0, yylineno);
				}
			}
			| DECR lvalue { 
				printf("term: DECR lvalue\n"); 
				// lecture 10 slide 34
				if($2->type == tableitem_e){
					$$ = emit_iftableitem($2);
					emit(sub, $$, newexpr_constnum(1), $$, 0, yylineno);
					emit(tablesetelem, $2, $2->index, $$, 0, yylineno);
				}else{
					emit(sub, $2, newexpr_constnum(1), $2, 0, yylineno);
					$$ = newexpr(arithexpr_e);
					$$->sym = newtemp();
					emit(assign, $2, NULL, $$, 0, yylineno);
				}
			}
			| lvalue DECR { 
				printf("term: lvalue DECR\n"); 
				// lecture 10 slide 33
				$$ = newexpr(var_e);
				$$->sym = newtemp();

				if($1->type == tableitem_e){
					struct expr *value = emit_iftableitem($1);
					emit(assign, $1, NULL, $$, 0, yylineno);
					emit(sub, value, newexpr_constnum(1), value, 0, yylineno);
					emit(tablesetelem, $1, $1->index, value, 0, yylineno);
				}else{
					emit(assign, $1, NULL, $$, 0, yylineno);
					emit(sub, $1, newexpr_constnum(1), $1, 0, yylineno);
				}
			}
			| primary { 
				printf("term: primary\n"); 
				$$ = $1;
			}
			;

assignexpr:	lvalue ASSIGN expr { 
							printf("assignexpr: lvalue ASSIGN expr\n");
							// lecture 10 slide 23
							if($1->type == tableitem_e){
								emit(tablesetelem, $1, $1->index, $3, 0, yylineno);
								$$ = emit_iftableitem($1);
								$$->type = assignexpr_e;
							}else{
								emit(assign, $3, NULL, $1, 0, yylineno);
								$$ = newexpr(assignexpr_e);
								$$->sym = newtemp();
								emit(assign, $1, NULL, $$, 0, yylineno);
							}
						}
						;

primary:	lvalue { 
						printf("primary: lvalue\n"); 
						$$ = emit_iftableitem($1);
					}
					| call { printf("primary: call\n"); }
					| objectdef { 
						printf("primary: objectdef\n"); 
						$$ = $1;
					}
					| LPARETH funcdef RPARETH { 
						printf("primary: LPARETH funcdef RPARETH\n"); 
						// lecture 10 - slide 31
						$$ = newexpr(programfunc_e);
						$$->sym = $2;
					}
					| const { 
						printf("primary: const\n"); 
						$$ = $1;
					}
					;

lvalue:	IDENT { 
						printf("lvalue: IDENT(%s)\n", $1); 
						
						int i;
						SymbolTableEntry *sym = NULL;

						for(i = scope; i >= 0; i--){
							sym = symbol_table_lookup($1, i);
							if(sym != NULL)
								break;
						}

						if(sym == NULL){ // den vrethike pouthena kai to vazoume se oti scope eimaste
								Variable *v = malloc(sizeof(Variable));
								v->name = strdup($1);
								v->scope = scope;
								v->line = yylineno;
								sym = symbol_table_insert(v, (scope == 0)?(GLOBAL):(LOCALL));

								// phasi 3 - 9:48
								sym->space = currscopespace();
								sym->offset = currscopeoffset();
								inccurrscopeoffset();
						}else{ // vrethike kai prepei na elegksoume an exoume prosvasi sto symvolo
							if(sym->type == USERFUNC || sym->type == LIBFUNC){
								// ok?
							}else{ // variable
								//if(s->value.varVal->scope < scope && function_counter > 0){
								//printf("ERROR: Den exoume prosvasi sto \"%s\" at line %u\n", s->value.varVal->name, yylineno);
								//}
							}
						}

						// phasi 3 - to sym exei sigoura timi
						$$ = lvalue_expr(sym); // 9:48
					}
				| LOCAL IDENT { 
						printf("lvalue: LOCAL IDENT(%s)\n", $2);

						SymbolTableEntry *sym = symbol_table_lookup($2, scope);
						if(sym == NULL){
							// prwta elegxoume ama kanei conflict me library function
							if(is_libfunc($2)){
								printf("ERROR: trying to shadow libfunc \"%s\" at line %u\n", $2, yylineno);
								exit(1);
							}else{
								Variable *v = malloc(sizeof(Variable));
								v->name = strdup($2);
								v->scope = scope;
								v->line = yylineno;
								sym = symbol_table_insert(v, (scope == 0)?(GLOBAL):(LOCALL));

								// phasi 3 - 9:48
								sym->space = currscopespace();
								sym->offset = currscopeoffset();
								inccurrscopeoffset();
							}
						} // else // vrethike kati kai anaferomaste se ayto

						// phasi 3 - to sym exei sigoura timi
						$$ = lvalue_expr(sym); // 9:48
					}
				| DCOLON IDENT { 
						printf("lvalue: DCOLON IDENT(%s)\n", $2); 

						SymbolTableEntry *sym = symbol_table_lookup($2, 0);
						if(sym == NULL){
							printf("ERROR: \"%s\" is not found at global scope at line %u\n", $2, yylineno);
							exit(1);
						} // else // vrethike kati kai anaferomaste se ayto

						// to sym den exei panta timi. mhpws prepei na stamatame sta errors?
						$$ = lvalue_expr(sym); // 10:18
					}
				| member { 
					printf("lvalue: member\n"); 
					$$ = $1;
				}
				;

member:	lvalue DOT IDENT { 
					printf("member: lvalue DOT IDENT\n"); 
					$$ = member_item($1, $3); // lect 10 slide 22
				}
				| lvalue LBRACKET expr RBRACKET { 
					printf("member: lvalue LBRACKET expr RBRACKET\n"); 
					// lect 10 slide 22
					$1 = emit_iftableitem($1);
					$$ = newexpr(tableitem_e);
					$$->sym = $1->sym;
					$$->index = $3;
				}
				| call DOT IDENT { printf("member: call DOT IDENT\n"); }
				| call LBRACKET expr RBRACKET { printf("member: call LBRACKET expr RBRACKET\n"); }
				;

call:	call LPARETH elist RPARETH { 
				printf("call: call LPARETH elist RPARETH\n"); 
				$$ = make_call($1, $3);
			}
			| lvalue callsuffix { 
				printf("call: lvalue callsuffix\n"); 
				// lexture 10 slide 28
				if($2->method == 1){
					struct expr *self = $1;
					$1 = emit_iftableitem(member_item(self, $2->name));
					self->next = $2->elist;
					$2->elist = self;
				}
				$$ = make_call($1, $2->elist);
			}
			| LPARETH funcdef RPARETH LPARETH elist RPARETH { 
				printf("call: LPARETH funcdef RPARETH LPARETH elist RPARETH\n"); 
				struct expr *func = newexpr(programfunc_e);
				func->sym = $2;
				$$ = make_call(func, $5);
			}
			;

callsuffix:	normcall { $$ = $1; printf("callsuffix: normcall\n"); }
						| methodcall { $$ = $1; printf("callsuffix: methodcall\n"); }
						;

normcall:	LPARETH elist RPARETH { 
						printf("normcall: LPARETH elist RPARETH\n"); 
						$$ = malloc(sizeof(struct methodcall));
						$$->elist = $2;
						$$->method = 0;
						$$->name = NULL;
					}
					;

methodcall:	DDOT IDENT LPARETH elist RPARETH { 
							printf("methodcall: DDOT IDENT LPARETH elist RPARETH\n"); 
							$$ = malloc(sizeof(struct methodcall));
							$$->elist = $4;
							$$->method = 1;
							$$->name = $2;
						}
						; 

elist:	expr COMMA elist { 
					printf("elist: expr COMMA elist\n"); 
					$1->next = $3;
					$$ = $1;
				}
				| expr { 
					printf("elist: expr\n"); 
					$$ = $1;
				}
				| { 
					printf("elist: empty\n"); 
					$$ = NULL;
				}
				;

objectdef:	LBRACKET elist RBRACKET { 
							printf("objectdef: LBRACKET elist RBRACKET\n"); 
							//lecture 10 slide 29
							$$ = newexpr(newtable_e);
							$$->sym = newtemp();
							emit(tablecreate, NULL, NULL, $$, 0, yylineno);
							unsigned int i = 0;
							struct expr *tmp;
							for(tmp = $2; tmp != NULL; tmp = tmp->next)
								emit(tablesetelem, $$, newexpr_constnum(i++), tmp, 0, yylineno);
						}
						| LBRACKET indexed RBRACKET { 
							printf("objectdef: LBRACKET indexed RBRACKET\n"); 
							//lecture 10 slide 30
							$$ = newexpr(newtable_e);
							$$->sym = newtemp();
							emit(tablecreate, NULL, NULL, $$, 0, yylineno);
							struct expr *tmp;
							for(tmp = $2; tmp != NULL; tmp = tmp->next)
								emit(tablesetelem, $$, tmp->index, tmp, 0, yylineno);
						}
						;

indexed:	indexedelem COMMA indexed { 
						printf("indexed: indexedelem COMMA indexed\n"); 
						$1->next = $3;
						$$ = $1;
					}
					| indexedelem { 
						printf("indexed: indexedelem\n"); 
						$$ = $1;
					}
					;

indexedelem:	LBRACE expr COLON expr RBRACE { 
								printf("indexedelem: LBRACE expr COLON expr RBRACE\n"); 
								$$ = $4;
								$$->index = $2;
							}
							;

block:	LBRACE RBRACE { printf("block: LBRACE RBRACE\n"); }
				| LBRACE stmts RBRACE { printf("block: LBRACE stmts RBRACE\n"); }
				;

funcname:	IDENT { $$ = $1; }	
					| { $$ = get_userfunc_name(); }
					;

funcprefix: FUNCTION funcname { 
							$$ = symbol_table_lookup($2, scope);
							if($$ == NULL){ // den vrethike
								// prwta elegxoume ama kanei conflict me library function
								if(is_libfunc($2)){
									printf("ERROR: a userfunc is trying to shadow a libfunc \"%s\" at line %u\n", $2, yylineno);
									exit(1);
								}else{
									Function *f = malloc(sizeof(Function));
									f->name = strdup($2);
									f->scope = scope;
									f->line = yylineno;
									$$ = symbol_table_insert(f, USERFUNC);
								}
							}else{
								printf("ERROR: cannot define a userfunc with name \"%s\" as it already exists in the same scope at line %u\n", $2, yylineno);
								exit(1);
							}
	
							// lecture 10 - slide 5
							$$->iaddress = nextquad();
							emit(funcstart, NULL, NULL, lvalue_expr($$), 0, yylineno);
							push(functionLocalsStack, functionLocalOffset);
							enterscopespace();
							resetformalargsoffset();

							// phasi 2
							++scope; 
							++function_counter; 
						}
						;

funcargs: LPARETH idlist RPARETH {
						enterscopespace();
						resetfunctionlocalsoffset();
					}
					;

funcbody: block {
						exitscopespace();
					}
					;

funcdef:	funcprefix funcargs funcbody { 
						// lecture 10 - slide 7
						enterscopespace();
						$1->totallocals = functionLocalOffset;
						functionLocalOffset = pop(functionLocalsStack);
						$$ = $1;
						emit(funcend, NULL, NULL, lvalue_expr($$), 0, yylineno);

						// phasi 2
						function_counter--;
						symbol_table_hide(scope--); 
					}
					;

const:	INTCONST { 
					printf("const: INTCONST(%d)\n", $1); 
					$$ = newexpr(constnum_e);
					$$->numConst = $1;
				}
				| REALCONST { 
					printf("const: REALCONST(%lf)\n", $1); 
					$$ = newexpr(constnum_e);
					$$->numConst = $1;	
				}
				| STRING { 
					printf("const: STRING(%s)\n", $1); 
					$$ = newexpr_conststring($1);
				}
				| NIL { 
					printf("const: NIL\n"); 
					$$ = newexpr(nil_e);
				}
				| TRUE { 
					printf("const: TRUE\n"); 
					$$ = newexpr(constbool_e);
					$$->boolConst = 1;
				}
				| FALSE { 
					printf("const: FALSE\n"); 
					$$ = newexpr(constbool_e);
					$$->boolConst = 0;
				}
				;

idlist2:	IDENT COMMA idlist2 { 
							printf("idlist2: IDENT(%s) COMMA idlist2\n", $1); 

							SymbolTableEntry *s = symbol_table_lookup($1, scope);
							if(s == NULL){
								if(is_libfunc($1)){
									printf("ERROR: cannot define a function argument with name \"%s\" as it conficts with a libfunc at line %u\n", $1, yylineno);
									exit(1);
								}else{
									Variable *v = malloc(sizeof(Variable));
									v->name = strdup($1);
									v->scope = scope;
									v->line = yylineno;
									symbol_table_insert(v, FORMAL);
								}
							}else{
								printf("ERROR: cannot define a function argument with name \"%s\" as it already exists at line %u\n", $1, yylineno);
								exit(1);
							}
						}
					| IDENT { 
							printf("idlist2: IDENT(%s)\n", $1); 
					
							SymbolTableEntry *s = symbol_table_lookup($1, scope);
							if(s == NULL){
								if(is_libfunc($1)){
									printf("ERROR: cannot define a function argument with name \"%s\" as it conficts with a libfunc at line %u\n", $1, yylineno);
									exit(1);
								}else{
									Variable *v = malloc(sizeof(Variable));
									v->name = strdup($1);
									v->scope = scope;
									v->line = yylineno;
									symbol_table_insert(v, FORMAL);
								}
							}else{
								printf("ERROR: cannot define a function argument with name \"%s\" as it already exists at line %u\n", $1, yylineno);
								exit(1);
							}
						}
					;

idlist:	idlist2 { printf("idlist: idlist2\n"); }
				| { printf("idlist: empty\n"); }
				;

ifprefix: IF LPARETH expr RPARETH {
						emit(if_eq, $3, newexpr_constbool(1), NULL, nextquad()+2, yylineno);
						$$ = nextquad();
						emit(jump, NULL, NULL, NULL, 0, yylineno);
					}
					;

elseprefix: ELSE {
							$$ = nextquad();
							emit(jump, NULL, NULL, NULL, 0, yylineno);
						}
						;

ifstmt:	ifprefix stmt %prec THEN { 
					printf("ifstmt: IF LPARETH expr RPARETH stmt\n"); 
					patchlabel($1, nextquad());
				}
				| ifprefix stmt elseprefix stmt { 
					printf("ifstmt: IF LPARETH expr RPARETH stmt ELSE stmt\n"); 
					patchlabel($1, $3+1);
					patchlabel($3, nextquad());
				}
				;

whilestart: WHILE {
							$$ = nextquad();
						}
						;

whilecond: 	LPARETH expr RPARETH {
							emit(if_eq, $2, newexpr_constbool(1), NULL, nextquad()+2, yylineno);
							$$ = nextquad();
							emit(jump, NULL, NULL, NULL, 0, yylineno);
						}
						;

whilestmt:	whilestart whilecond { ++loop_counter; } stmt { 
							--loop_counter;
							printf("whilestmt: WHILE LPARETH expr RPARETH stmt\n"); 

							emit(jump, NULL, NULL, NULL, $1, yylineno);
							patchlabel($2, nextquad());
							// patchlabel(stmt.breaklist,nextquad());
							// patchlabel(stmt.contlist,$1);
						}

forN:	{
				$$ = nextquad();
				emit(jump, NULL, NULL, NULL, 0, yylineno);
			}
			;

forM: {
				$$ = nextquad();
			}
			;

forprefix:	FOR LPARETH elist SEMICOLON forM expr SEMICOLON {
							$$ = malloc(sizeof(struct forpref));
							$$->test = $5;
							$$->enter = nextquad();
							emit(if_eq, $6, newexpr_constbool(1), NULL, 0, yylineno);
						}
						;

forstmt:	forprefix forN elist RPARETH forN { ++loop_counter; } stmt forN { 
							--loop_counter;
							printf("forstmt: FOR LPARETH elist SEMICOLON expr SEMICOLON elist RPARETH stmt\n"); 

							patchlabel($1->enter, $5 + 1);
							patchlabel($2, nextquad());
							patchlabel($5, $1->test);
							patchlabel($8, $2 + 1);

							// patchlabel(stmt.breaklist,nextquad());
							// patchlabel(stmt.contlist,$2 + 1);
					}
					;

returnstmt:	RETURN SEMICOLON { 
							printf("returnstmt: RETURN SEMICOLON\n"); 
							if(function_counter < 1){
								printf("ERROR: cannot have a return outside a function at line %u\n", yylineno);
								exit(1);
							}
							emit(ret, NULL, NULL, NULL, 0, yylineno);
						}
						| RETURN expr SEMICOLON { 
							printf("returnstmt: RETURN expr SEMICOLON\n"); 
							if(function_counter < 1){
								printf("ERROR: cannot have a return outside a function at line %u\n", yylineno);
								exit(1);
							}
							emit(ret, NULL, NULL, $2, 0, yylineno);
						}
						;

%%

int yyerror(char *yaccProvidedMessage)
{
	fprintf(stderr, "%s: at line %d, before token: %s\n", yaccProvidedMessage, yylineno, yytext);
	fprintf(stderr, "INPUT NOT VALID\n");
	return 0;
}

int main(int argc, char **argv)
{
	int i;

  if(argc > 1){
    if(!(yyin = fopen(argv[1], "r"))){
      fprintf(stderr, "Cannot read file: %s\n", argv[1]);
      return 1;
    }
  }else
    yyin = stdin;

	symbol_table_init();
	functionLocalsStack = new_stack();

	for(i = 0; i < NUM_LIBFUNCS; i++)
		symbol_table_insert_libfunc(libfunc[i]);

	yyparse();

	printf("\n\n");
	symbol_table_print();

	printf("\n\n");
	print_quads();

	printf("\n\n");
	generate_instructions();

	printf("\n\n");
	create_binaryfile("test.bin");

	return 0;
}



