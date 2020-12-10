#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stddef.h>

#include "symbol_table.h"

#define HASH_MULTIPLIER 65599

static SymbolTableNode *hash[HASH_ENTRIES];
static SymbolTableNode *scope_list[MAX_SCOPE_LISTS];

void symbol_table_init(void)
{
	int i;

	for(i = 0; i < HASH_ENTRIES; i++)
		hash[i] = NULL;

	for(i = 0; i < MAX_SCOPE_LISTS; i++)
		scope_list[i] = NULL;
}

/* Return a hash code for pcKey. */
static unsigned int SymTable_hash(const char *pcKey)
{
	size_t ui;
	unsigned int uiHash = 0U;
	for (ui = 0U; pcKey[ui] != '\0'; ui++)
		uiHash = uiHash * HASH_MULTIPLIER + pcKey[ui];
	return uiHash % HASH_ENTRIES;
} 

void symbol_table_insert(void *d, enum SymbolTableType type)
{
	unsigned int hash_id, scope;
	SymbolTableEntry *tmp;
	SymbolTableNode *node;

	tmp = malloc(sizeof(SymbolTableEntry));
	tmp->isActive = 1;
	tmp->type = type;

	node = malloc(sizeof(SymbolTableNode));
	node->data = tmp;
	node->hnext = NULL;
	node->snext = NULL;
	
	if(type == USERFUNC || type == LIBFUNC){
		tmp->value.funcVal = (Function *)d;
		node->key = ((Function *)d)->name;
		scope = ((Function *)d)->scope;
	}else{
		tmp->value.varVal = (Variable *)d;
		node->key = ((Variable *)d)->name;
		scope = ((Variable *)d)->scope;
	}
		
	hash_id = SymTable_hash(node->key);

	// prwta to vazoume sto hash-table
	if(hash[hash_id] == NULL){
		hash[hash_id] = node;
	}else{
		node->hnext = hash[hash_id];
		hash[hash_id] = node;
	}

	// kai meta sthn arxh ths scope list
	if(scope_list[scope] == NULL){
		scope_list[scope] = node;
	}else{
		node->snext = scope_list[scope];
		scope_list[scope] = node;
	}
}

void symbol_table_insert_libfunc(const char *name)
{
  Function *f = malloc(sizeof(Function));
	f->name = strdup(name);
	f->scope = 0;
	f->line = 0;
	symbol_table_insert(f, LIBFUNC);
}

void symbol_table_hide(unsigned int scope)
{
	SymbolTableNode *tmp;

	for(tmp = scope_list[scope]; tmp != NULL; tmp = tmp->snext)
		tmp->data->isActive = 0;
}

SymbolTableEntry *symbol_table_lookup(const char *name, unsigned int scope)
{
	SymbolTableNode *tmp;

	for(tmp = scope_list[scope]; tmp != NULL; tmp = tmp->snext)
		if(strcmp(tmp->key, name) == 0)
			if(tmp->data->isActive)
				return tmp->data;

	return NULL;
}

void symbol_table_print(void)
{
	int i;
	SymbolTableNode *tmp;

	for(i = 0; i < HASH_ENTRIES; i++)
		for(tmp = hash[i]; tmp != NULL; tmp = tmp->hnext){
			if(tmp->data->type == LIBFUNC){
				printf("Library function with name: \"%s\" scope: %u line: %u\n", tmp->key, tmp->data->value.funcVal->scope, tmp->data->value.funcVal->line);
			}else if(tmp->data->type == USERFUNC){
				printf("User function with name: \"%s\" scope: %u line: %u\n", tmp->key, tmp->data->value.funcVal->scope, tmp->data->value.funcVal->line);
			}else if(tmp->data->type == GLOBAL){
				printf("Global variable with name: \"%s\" scope: %u line: %u\n", tmp->key, tmp->data->value.varVal->scope, tmp->data->value.varVal->line);
			}else if(tmp->data->type == LOCALL){
				printf("Local variable with name: \"%s\" scope: %u line: %u\n", tmp->key, tmp->data->value.varVal->scope, tmp->data->value.varVal->line);
			}else if(tmp->data->type == FORMAL){
				printf("Formal argument with name: \"%s\" scope: %u line: %u\n", tmp->key, tmp->data->value.varVal->scope, tmp->data->value.varVal->line);
			}
		}
}
