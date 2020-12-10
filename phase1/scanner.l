%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define YY_DECL int alpha_yylex(void *yylval)

enum category { KEYWORD, OPERATOR, INTCONST, REALCONST, STRING, PUNCTUATION_MARK, IDENT };
enum keyword { IF, ELSE, WHILE, FOR, FUNCTION, RETURN, BREAK, CONTINUE, AND, NOT, OR, LOCAL, TRUE, FALSE, NIL};
enum operator { ASSIGN, ADD, SUB, MUL, DIV, MOD, EQ, NEQ, INCR, DECR, GT, LT, GEQ, LEQ };
enum punctuation { LBRACE, RBRACE, LBRACKET, RBRACKET, LPARETH, RPARETH, SEMICOLON, COMMA, COLON, DCOLON, DOT, DDOT };

unsigned int count = 1;

typedef struct {
	enum category cat;

	/* analoga me to category xrhsimopoioume kai ena apo ta parakatw */
	enum keyword kw;
	enum operator op;
	enum punctuation pun;
	char *str; /* idio gia string kai ident */
	int intconst;
	double realconst;

	char *data;
	unsigned int num;
	unsigned int line;
} alpha_token_t;

const char *category_to_string(enum category c)
{
	if(c == KEYWORD) return "KEYWORD";
	else if(c == OPERATOR) return "OPERATOR";
	else if(c == INTCONST) return "INTCONST";
	else if(c == REALCONST) return "REALCONST";
	else if(c == STRING) return "STRING";
	else if(c == PUNCTUATION_MARK) return "PUNCTUATION_MARK";
	else if(c == IDENT) return "IDENT";
	return "LATHOS!!";
}

const char *keyword_to_string(enum keyword k)
{
	if(k == IF) return "IF";
	else if(k == ELSE) return "ELSE";
	else if(k == WHILE) return "WHILE";
	else if(k == FOR) return "FOR";
	else if(k == FUNCTION) return "FUNCTION";
	else if(k == RETURN ) return "RETURN";
	else if(k == BREAK) return "BREAK";
	else if(k == CONTINUE) return "CONTINUE";
	else if(k == AND) return "AND";
	else if(k == NOT) return "NOT";
	else if(k == OR) return "OR";
	else if(k == LOCAL) return "LOCAL";
	else if(k == TRUE) return "TRUE";
	else if(k == FALSE) return "FALSE";
	else if(k == NIL) return "NIL";
	return "LATHOS!!";
}

const char *operator_to_string(enum operator o)
{
	if(o == ASSIGN) return "ASSIGN";
	else if(o == ADD) return "ADD";
	else if(o == SUB) return "SUB";
	else if(o == MUL) return "MUL";
	else if(o == DIV) return "DIV";
	else if(o == MOD) return "MOD";
	else if(o == EQ) return "EQ";
	else if(o == NEQ) return "NEQ";
	else if(o == INCR) return "INCR";
	else if(o == DECR) return "DECR";
	else if(o == GT) return "GT";
	else if(o == LT) return "LT";
	else if(o == GEQ) return "GEQ";
	else if(o == LEQ) return "LEQ";
	return "LATHOS!!";
}

const char *punctuation_to_string(enum punctuation p)
{
	if(p == LBRACE) return "LEFT_BRACE";
	else if(p == RBRACE) return "RIGHT_BRACE";
	else if(p == LBRACKET) return "LEFT_BRACKET";
	else if(p == RBRACKET) return "RIGHT_BRACKET";
	else if(p == LPARETH) return "LEFT_PARENTHESIS";
	else if(p == RPARETH) return "RIGHT_PARENTHESIS";
	else if(p == SEMICOLON) return "SEMICOLON";
	else if(p == COMMA) return "COMMA";
	else if(p == COLON) return "COLON";
	else if(p == DCOLON) return "DOUBLE_COLON";
	else if(p == DOT) return "DOT";
	else if(p == DDOT) return "DOUBLE_DOT";
	return "LATHOS!!";
}

int set_keyword(void *yylval, unsigned int line, char *data, enum keyword k)
{
	alpha_token_t *at = (alpha_token_t *)yylval;

	at->line = line;
	at->num = count++;
	at->data = strdup(data);
	at->cat = KEYWORD;
	at->kw = k;

	return 1;
}

int set_operator(void *yylval, unsigned int line, char *data, enum operator o)
{
	alpha_token_t *at = (alpha_token_t *)yylval;

	at->line = line;
	at->num = count++;
	at->data = strdup(data);
	at->cat = OPERATOR;
	at->op = o;

	return 1;
}

int set_punctuation(void *yylval, unsigned int line, char *data, enum punctuation p)
{
	alpha_token_t *at = (alpha_token_t *)yylval;

	at->line = line;
	at->num = count++;
	at->data = strdup(data);
	at->cat = PUNCTUATION_MARK;
	at->pun = p;

	return 1;
}

%}

/* flex options */
%option noyywrap
%option yylineno

/* flex macros */
id 					[a-zA-Z][a-zA-Z_0-9]*
line_comment "//".*
intconst		[0-9]+
realconst		[0-9]+"."[0-9]+

kw_if	"if"
kw_else "else"
kw_while "while"
kw_for "for"
kw_function "function"
kw_return "return"
kw_break "break"
kw_continue "continue"
kw_and "and"
kw_or "or"
kw_not "not"
kw_local "local"
kw_true "true"
kw_false "false"
kw_nil "nil"

assign "="
add "+"
sub "-"
mul "*"
div "/"
mod "%"
eq "=="
neq "!="
incr "++"
decr "--"
gt ">"
lt "<"
geq ">="
leq "<="

lbrace "{"
rbrace "}"
lbracket "["
rbracket "]"
lparenth "("
rparenth ")"
semicolon ";"
comma ","
colon ":"
dcolon "::"
dot "."
ddot ".."

%%

<<EOF>>				{ fprintf(stderr, "Recognized EOF\n"); return 0; }

"/*" {
	int c;
	int comments = 1;

	while((c = input()) != EOF){
		if(c == '*'){
			if((c = input()) != EOF){
				if(c == '/'){
					if(--comments == 0)
						break;
				}else
					unput(c);
			}else
				return -1;
		}else if(c == '/'){
			if((c = input()) != EOF){
				if(c == '*')
					comments++;
				else
					unput(c);
			}else
				return -1;
		}
	}
}

{line_comment} /* ingnore it */

{kw_if} { return set_keyword(yylval, yylineno, yytext, IF); }
{kw_else}  { return set_keyword(yylval, yylineno, yytext, ELSE); }
{kw_while} { return set_keyword(yylval, yylineno, yytext, WHILE); }
{kw_for} { return set_keyword(yylval, yylineno, yytext, FOR); }
{kw_function} { return set_keyword(yylval, yylineno, yytext, FUNCTION); }
{kw_return} { return set_keyword(yylval, yylineno, yytext, RETURN); }
{kw_break} { return set_keyword(yylval, yylineno, yytext, BREAK); }
{kw_continue} { return set_keyword(yylval, yylineno, yytext, CONTINUE); }
{kw_and} { return set_keyword(yylval, yylineno, yytext, AND); }
{kw_not} { return set_keyword(yylval, yylineno, yytext, NOT); }
{kw_or} { return set_keyword(yylval, yylineno, yytext, OR); }
{kw_local} { return set_keyword(yylval, yylineno, yytext, LOCAL); }
{kw_true} { return set_keyword(yylval, yylineno, yytext, TRUE); }
{kw_false} { return set_keyword(yylval, yylineno, yytext, FALSE); }
{kw_nil} { return set_keyword(yylval, yylineno, yytext, NIL); }

{assign} { return set_operator(yylval, yylineno, yytext, ASSIGN); }
{add} { return set_operator(yylval, yylineno, yytext, ADD); }
{sub} { return set_operator(yylval, yylineno, yytext, SUB); }
{mul} { return set_operator(yylval, yylineno, yytext, MUL); }
{div} { return set_operator(yylval, yylineno, yytext, DIV); }
{mod} { return set_operator(yylval, yylineno, yytext, MOD); }
{eq} { return set_operator(yylval, yylineno, yytext, EQ); }
{neq} { return set_operator(yylval, yylineno, yytext, NEQ); }
{incr} { return set_operator(yylval, yylineno, yytext, INCR); }
{decr} { return set_operator(yylval, yylineno, yytext, DECR); }
{gt} { return set_operator(yylval, yylineno, yytext, GT); }
{lt} { return set_operator(yylval, yylineno, yytext, LT); }
{geq} { return set_operator(yylval, yylineno, yytext, GEQ); }
{leq} { return set_operator(yylval, yylineno, yytext, LEQ); }

{lbrace} { return set_punctuation(yylval, yylineno, yytext, LBRACE); }
{rbrace} { return set_punctuation(yylval, yylineno, yytext, RBRACE); }
{lbracket} { return set_punctuation(yylval, yylineno, yytext, LBRACKET); }
{rbracket} { return set_punctuation(yylval, yylineno, yytext, RBRACKET); }
{lparenth} { return set_punctuation(yylval, yylineno, yytext, LPARETH); }
{rparenth} { return set_punctuation(yylval, yylineno, yytext, RPARETH); }
{semicolon} { return set_punctuation(yylval, yylineno, yytext, SEMICOLON); }
{comma} { return set_punctuation(yylval, yylineno, yytext, COMMA); }
{colon} { return set_punctuation(yylval, yylineno, yytext, COLON); }
{dcolon} { return set_punctuation(yylval, yylineno, yytext, DCOLON); }
{dot} { return set_punctuation(yylval, yylineno, yytext, DOT); }
{ddot} { return set_punctuation(yylval, yylineno, yytext, DDOT); }

{id} { 
	alpha_token_t *at = (alpha_token_t *)yylval;
	at->line = yylineno;
	at->num = count++;
	at->data = strdup(yytext);
	at->cat = IDENT;
	at->str = strdup(yytext);
	return 1;
}

{intconst} {
	alpha_token_t *at = (alpha_token_t *)yylval;
	at->line = yylineno;
	at->num = count++;
	at->data = strdup(yytext);
	at->cat = INTCONST;
	at->intconst = atoi(yytext);
	return 1;
}

{realconst} {
	alpha_token_t *at = (alpha_token_t *)yylval;
	at->line = yylineno;
	at->num = count++;
	at->data = strdup(yytext);
	at->cat = REALCONST;
	at->realconst = atof(yytext);
	return 1;
}
	
"\"" { 
	int len = 16;
	char *str = malloc(len * sizeof(char)); /* arxika desmeyoume xwro gia 16 xarakthres */
	int idx = 0;
	int c;
	alpha_token_t *at = (alpha_token_t *)yylval;

	at->line = yylineno;
	at->num = count++;
	at->cat = STRING;

	while((c = input()) != EOF){
		if(idx == (len - 1)){ /* desmeyoume xwro ama den xwraei to string */
			char *new_str = malloc((len + 16) * sizeof(char));
			strcpy(new_str, str);
			free(str);
			len += 16;
			str = new_str;
		}

		if(c == '\"'){
			str[idx] = '\0';
			at->str = strdup(str);
			at->data= strdup(str);
			free(str);
			return 1;
		}else if(c == '\\'){
			if((c = input()) != EOF){
				if(c == 'n'){
					str[idx++] = '\n';
				}else if(c == 't'){
					str[idx++] = '\t';
				}else if(c == '\\'){
					str[idx++] = '\\';
				}else if(c == '\"'){
					str[idx++] = '"';
				}else{
					str[idx++] = '\\';
					unput(c);
				}
			}else{
				return -1;
			}
		}else{
			str[idx++] = c;
		}
	}

	return -1;
}

[ \t\n\r] /* whitespace */

. { 
	fprintf(stderr, "Cannot match character '%s' with any rule\n", yytext); 
	return 0; 
}

%%

int main(int argc, char **argv)
{
	alpha_token_t token;

	if(argc > 1){
		if(!(yyin = fopen(argv[1], "r"))){
			fprintf(stderr, "Cannot read file: %s\n", argv[1]);
			return 1;
		}
	}else
		yyin = stdin;

	while(1){
		int ret = alpha_yylex(&token);
		if(ret == 0){
			break;
		}else if(ret < 0){
			fprintf(stderr, "ERROR on input!\n");
			break;
		}else{
			if(token.cat == KEYWORD)
				fprintf(stdout, "%u: #%u \"%s\" %s %s\n", token.line, token.num, token.data, category_to_string(token.cat), keyword_to_string(token.kw));
			else if(token.cat == INTCONST)
				fprintf(stdout, "%u: #%u \"%s\" %s %d\n", token.line, token.num, token.data, category_to_string(token.cat), token.intconst);
			else if(token.cat == REALCONST)
				fprintf(stdout, "%u: #%u \"%s\" %s %lf\n", token.line, token.num, token.data, category_to_string(token.cat), token.realconst);
			else if(token.cat == OPERATOR)
				fprintf(stdout, "%u: #%u \"%s\" %s %s\n", token.line, token.num, token.data, category_to_string(token.cat), operator_to_string(token.op));
			else if(token.cat == PUNCTUATION_MARK)
				fprintf(stdout, "%u: #%u \"%s\" %s %s\n", token.line, token.num, token.data, category_to_string(token.cat), punctuation_to_string(token.pun));
			else if((token.cat == STRING) || (token.cat == IDENT))
				fprintf(stdout, "%u: #%u \"%s\" %s \"%s\"\n", token.line, token.num, token.data, category_to_string(token.cat), token.str);
			else
				fprintf(stdout, "lathos category!\n");
		}
	}

	return 0;
}
