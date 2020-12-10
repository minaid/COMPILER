%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parser.h"
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

<<EOF>>				{ return 0; }

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

{kw_if} { return IF; }
{kw_else}  { return ELSE; }
{kw_while} { return WHILE; }
{kw_for} { return FOR; }
{kw_function} { return FUNCTION; }
{kw_return} { return RETURN; }
{kw_break} { return BREAK; }
{kw_continue} { return CONTINUE; }
{kw_and} { return AND; }
{kw_not} { return NOT; }
{kw_or} { return OR; }
{kw_local} { return LOCAL; }
{kw_true} { return TRUE; }
{kw_false} { return FALSE; }
{kw_nil} { return NIL; }

{assign} { return ASSIGN; }
{add} { return ADD; }
{sub} { return SUB; }
{mul} { return MUL; }
{div} { return DIV; }
{mod} { return MOD; }
{eq} { return EQ; }
{neq} { return NEQ; }
{incr} { return INCR; }
{decr} { return DECR; }
{gt} { return GT; }
{lt} { return LT; }
{geq} { return GEQ; }
{leq} { return LEQ; }

{lbrace} { return LBRACE; }
{rbrace} { return RBRACE; }
{lbracket} { return LBRACKET; }
{rbracket} { return RBRACKET; }
{lparenth} { return LPARETH; }
{rparenth} { return RPARETH; }
{semicolon} { return SEMICOLON; }
{comma} { return COMMA; }
{colon} { return COLON; }
{dcolon} { return DCOLON; }
{dot} { return DOT; }
{ddot} { return DDOT; }

{id} { yylval.str = strdup(yytext); return IDENT; }
{intconst} { yylval.intconst = atoi(yytext); return INTCONST; }
{realconst} { yylval.realconst = atof(yytext); return REALCONST; }
	
"\"" { 
	int len = 16;
	char *str = malloc(len * sizeof(char)); /* arxika desmeyoume xwro gia 16 xarakthres */
	int idx = 0;
	int c;

	while((c = input()) != EOF){
		if(idx == (len - 1)){ /* desmeyoume xwro ama den xwraei to string */
			char *new_str = malloc((len + 16) * sizeof(char));
			strcpy(new_str, str);
			free(str);
			len += 16;
			str = new_str;
		}

		if(c == '"'){ /* telos tou string */
			str[idx] = '\0';
			yylval.str = strdup(str);
			return STRING;
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
