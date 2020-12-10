%{
#include <stdio.h>
#include <string.h>

#include "symbol_table.h"

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

int is_libfunc(const char *s)
{
	int i;

	for(i = 0; i < NUM_LIBFUNCS; i++)
		if(strcmp(libfunc[i], s) == 0)
			return 1;

	return 0;
}

const char *get_userfunc_name(void)
{
	sprintf(no_name_userfunc_str, "$f%u", no_name_userfunc_num);
	++no_name_userfunc_num;
	return no_name_userfunc_str;
}

%}

%start program

%union {
	char *str; /* idio gia string kai ident */
	int intconst;
	double realconst;
}

%token <str> IDENT
%token <str> STRING
%token <intconst> INTCONST
%token <realconst> REALCONST

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
%nonassoc IF
%nonassoc ELSE

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
				}
				printf("stmt: BREAK SEMICOLON\n"); 
			}
			| CONTINUE SEMICOLON { 
				if(loop_counter < 1){
					printf("ERROR: cannot have a continue outside a loop at line %u\n", yylineno);
				}
				printf("stmt: CONTINUE SEMICOLON\n"); 
			}
			| { ++scope; } block  { symbol_table_hide(scope--); printf("stmt: block\n"); }
			| funcdef { printf("stmt: funcdef\n"); }
			| SEMICOLON { printf("stmt: SEMICOLON\n"); }
			;

expr:	assignexpr { printf("expr: assignexpr\n"); }
			| expr ADD expr { printf("expr: expr ADD expr\n"); }
			| expr SUB expr { printf("expr: expr SUB expr\n"); }
			| expr MUL expr { printf("expr: expr MUL expr\n"); }
			| expr DIV expr { printf("expr: expr DIV expr\n"); }
			| expr MOD expr { printf("expr: expr MOD expr\n"); }
			| expr GT expr { printf("expr: expr GT expr\n"); }
			| expr GEQ expr { printf("expr: expr GEQ expr\n"); }
			| expr LT expr { printf("expr: expr LT expr\n"); }
			| expr LEQ expr { printf("expr: expr LEQ expr\n"); }
			| expr EQ expr { printf("expr: expr EQ expr\n"); }
			| expr NEQ expr { printf("expr: expr NEQ expr\n"); }
			| expr AND expr { printf("expr: expr AND expr\n"); }
			| expr OR expr { printf("expr: expr OR expr\n"); }
			| term { printf("expr: term\n"); }
			;

term:	LPARETH expr RPARETH { printf("term: LPARETH expr RPARETH\n"); }
			| SUB expr %prec UMINUS { printf("term: SUB expr\n"); }
			| NOT expr { printf("term: NOT expr\n"); }
			| INCR lvalue { printf("term: INCR lvalue\n"); }
			| lvalue INCR { printf("term: lvalue INCR\n"); }
			| DECR lvalue { printf("term: DECR lvalue\n"); }
			| lvalue DECR { printf("term: lvalue DECR\n"); }
			| primary { printf("term: primary\n"); }
			;

assignexpr:	lvalue ASSIGN expr { printf("assignexpr: lvalue ASSIGN expr\n"); }
						;

primary:	lvalue { printf("primary: lvalue\n"); }
					| call { printf("primary: call\n"); }
					| objectdef { printf("primary: objectdef\n"); }
					| LPARETH funcdef RPARETH { printf("primary: LPARETH funcdef RPARETH\n"); }
					| const { printf("primary: const\n"); }
					;

lvalue:	IDENT { 
						printf("lvalue: IDENT(%s)\n", $1); 
						
						int i;
						SymbolTableEntry *s = NULL;

						for(i = scope; i >= 0; i--){
							s = symbol_table_lookup($1, i);
							if(s != NULL)
								break;
						}

						if(s == NULL){ // den vrethike pouthena kai to vazoume se oti scope eimaste
								Variable *v = malloc(sizeof(Variable));
								v->name = strdup($1);
								v->scope = scope;
								v->line = yylineno;
								symbol_table_insert(v, (scope == 0)?(GLOBAL):(LOCALL));
						}else{ // vrethike kai prepei na elegksoume an exoume prosvasi sto symvolo
							if(s->type == USERFUNC || s->type == LIBFUNC){
								// ok?
							}else{ // variable
						//		if(s->value.varVal->scope < scope && function_counter > 0){
					//				printf("ERROR: Den exoume prosvasi sto \"%s\" at line %u\n", s->value.varVal->name, yylineno);
				//				}
							}
						}
					}
				| LOCAL IDENT { 
						printf("lvalue: LOCAL IDENT(%s)\n", $2);

						SymbolTableEntry *s = symbol_table_lookup($2, scope);
						if(s == NULL){
							// prwta elegxoume ama kanei conflict me library function
							if(is_libfunc($2)){
								printf("ERROR: trying to shadow libfunc \"%s\" at line %u\n", $2, yylineno);
							}else{
								Variable *v = malloc(sizeof(Variable));
								v->name = strdup($2);
								v->scope = scope;
								v->line = yylineno;
								symbol_table_insert(v, (scope == 0)?(GLOBAL):(LOCALL));
							}
						} // else // vrethike kati kai anaferomaste se ayto
					}
				| DCOLON IDENT { 
						printf("lvalue: DCOLON IDENT(%s)\n", $2); 

						SymbolTableEntry *s = symbol_table_lookup($2, 0);
						if(s == NULL){
							printf("ERROR: \"%s\" is not found at global scope at line %u\n", $2, yylineno);
						} // else // vrethike kati kai anaferomaste se ayto
					}
				| member { printf("lvalue: member\n"); }
				;

member:	lvalue DOT IDENT { printf("member: lvalue DOT IDENT\n"); }
				| lvalue LBRACKET expr RBRACKET { printf("member: lvalue LBRACKET expr RBRACKET\n"); }
				| call DOT IDENT { printf("member: call DOT IDENT\n"); }
				| call LBRACKET expr RBRACKET { printf("member: call LBRACKET expr RBRACKET\n"); }
				;

call:	call LPARETH elist RPARETH { printf("call: call LPARETH elist RPARETH\n"); }
			| lvalue callsuffix { printf("call: lvalue callsuffix\n"); }
			| LPARETH funcdef RPARETH LPARETH elist RPARETH { printf("call: LPARETH funcdef RPARETH LPARETH elist RPARETH\n"); }
			;

callsuffix:	normcall { printf("callsuffix: normcall\n"); }
						| methodcall { printf("callsuffix: methodcall\n"); }
						;

normcall:	LPARETH elist RPARETH { printf("normcall: LPARETH elist RPARETH\n"); }
					;

methodcall:	DDOT IDENT LPARETH elist RPARETH { printf("methodcall: DDOT IDENT LPARETH elist RPARETH\n"); }
						; 

elist:	expr COMMA elist { printf("elist: expr COMMA elist\n"); }
				| expr { printf("elist: expr\n"); }
				| { printf("elist: empty\n"); }
				;

objectdef:	LBRACKET elist RBRACKET { printf("objectdef: LBRACKET elist RBRACKET\n"); }
						| LBRACKET indexed RBRACKET { printf("objectdef: LBRACKET indexed RBRACKET\n"); }
						;

indexed:	indexedelem COMMA indexed { printf("indexed: indexedelem COMMA indexed\n"); }
					| indexedelem { printf("indexed: indexedelem\n"); }
					;

indexedelem:	LBRACE expr COLON expr RBRACE { printf("indexedelem: LBRACE expr COLON expr RBRACE\n"); }
							;

block:	LBRACE RBRACE { printf("block: LBRACE RBRACE\n"); }
				| LBRACE stmts RBRACE { printf("block: LBRACE stmts RBRACE\n"); }
				;

funcname:	IDENT { 
							printf("funcname: IDENT(%s)\n", $1); 
						
							SymbolTableEntry *s = symbol_table_lookup($1, scope);
							if(s == NULL){ // den vrethike
								// prwta elegxoume ama kanei conflict me library function
								if(is_libfunc($1)){
									printf("ERROR: a userfunc is trying to shadow a libfunc \"%s\" at line %u\n", $1, yylineno);
								}else{
									Function *f = malloc(sizeof(Function));
									f->name = strdup($1);
									f->scope = scope;
									f->line = yylineno;
									symbol_table_insert(f, USERFUNC);
								}
							}else{
								printf("ERROR: cannot define a userfunc with name \"%s\" as it already exists in the same scope at line %u\n", $1, yylineno);
							}
						}
					| { 
							printf("funcname: empty\n"); 

							// afou exoume monadika onomata den xreiazete na elegksoume ama yparxei idio onoma
							// hdh dhlwmeno kai episis den mporei na kanei conflict me libfunc ara to vazoume 
							// xwris na elgksoume kati

							Function *f = malloc(sizeof(Function));
							f->name = strdup(get_userfunc_name());
							f->scope = scope;
							f->line = yylineno;
							symbol_table_insert(f, USERFUNC);
						}
					;

funcdef:	FUNCTION funcname { ++scope; ++function_counter; } LPARETH idlist RPARETH block { 
						function_counter--;
						symbol_table_hide(scope--); 
						printf("funcdef: FUNCTION funcname LPARETH idlist RPARETH block\n"); 
					}

const:	INTCONST { printf("const: INTCONST(%d)\n", $1); }
				| REALCONST { printf("const: REALCONST(%lf)\n", $1); }
				| STRING { printf("const: STRING(%s)\n", $1); }
				| NIL { printf("const: NIL\n"); }
				| TRUE { printf("const: TRUE\n"); }
				| FALSE { printf("const: FALSE\n"); }
				;

idlist2:	IDENT COMMA idlist2 { 
							printf("idlist2: IDENT(%s) COMMA idlist2\n", $1); 

							SymbolTableEntry *s = symbol_table_lookup($1, scope);
							if(s == NULL){
								if(is_libfunc($1)){
									printf("ERROR: cannot define a function argument with name \"%s\" as it conficts with a libfunc at line %u\n", $1, yylineno);
								}else{
									Variable *v = malloc(sizeof(Variable));
									v->name = strdup($1);
									v->scope = scope;
									v->line = yylineno;
									symbol_table_insert(v, FORMAL);
								}
							}else{
								printf("ERROR: cannot define a function argument with name \"%s\" as it already exists at line %u\n", $1, yylineno);
							}
						}
					| IDENT { 
							printf("idlist2: IDENT(%s)\n", $1); 
					
							SymbolTableEntry *s = symbol_table_lookup($1, scope);
							if(s == NULL){
								if(is_libfunc($1)){
									printf("ERROR: cannot define a function argument with name \"%s\" as it conficts with a libfunc at line %u\n", $1, yylineno);
								}else{
									Variable *v = malloc(sizeof(Variable));
									v->name = strdup($1);
									v->scope = scope;
									v->line = yylineno;
									symbol_table_insert(v, FORMAL);
								}
							}else{
								printf("ERROR: cannot define a function argument with name \"%s\" as it already exists at line %u\n", $1, yylineno);
							}
						}
					;

idlist:	idlist2 { printf("idlist: idlist2\n"); }
				| { printf("idlist: empty\n"); }
				;

ifstmt:	IF LPARETH expr RPARETH stmt { printf("ifstmt: IF LPARETH expr RPARETH stmt\n"); }
				| IF LPARETH expr RPARETH stmt ELSE stmt { printf("ifstmt: IF LPARETH expr RPARETH stmt ELSE stmt\n"); }

whilestmt:	WHILE LPARETH expr RPARETH { ++loop_counter; } stmt { 
							--loop_counter;
							printf("whilestmt: WHILE LPARETH expr RPARETH stmt\n"); 
						}

forstmt:	FOR LPARETH elist SEMICOLON expr SEMICOLON elist RPARETH { ++loop_counter; } stmt { 
							--loop_counter;
							printf("forstmt: FOR LPARETH elist SEMICOLON expr SEMICOLON elist RPARETH stmt\n"); 
					}
					;

returnstmt:	RETURN SEMICOLON { printf("returnstmt: RETURN SEMICOLON\n"); }
						| RETURN expr SEMICOLON { printf("returnstmt: RETURN expr SEMICOLON\n"); }
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

	for(i = 0; i < NUM_LIBFUNCS; i++)
		symbol_table_insert_libfunc(libfunc[i]);

	yyparse();

	printf("\n\n");
	symbol_table_print();

	return 0;
}



