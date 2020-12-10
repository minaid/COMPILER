#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#define HASH_ENTRIES 509
#define MAX_SCOPE_LISTS 20

typedef struct Variable {
	const char *name;
	unsigned int scope;
	unsigned int line;
} Variable;

typedef struct Function {
	const char *name;
	// list of arguments
	unsigned int scope;
	unsigned int line;
} Function;

enum SymbolTableType { GLOBAL, LOCALL, FORMAL, USERFUNC, LIBFUNC };

typedef struct SymbolTableEntry {
	int isActive;
	union {
		Variable *varVal;
		Function *funcVal;
	} value;
	enum SymbolTableType type;
} SymbolTableEntry;

typedef struct SymbolTableNode {
	const char *key;
	SymbolTableEntry *data;
	struct SymbolTableNode *hnext; // hash next
	struct SymbolTableNode *snext; // scope list next
} SymbolTableNode;

void symbol_table_init(void);
void symbol_table_insert(void *d, enum SymbolTableType type);
void symbol_table_insert_libfunc(const char *name);
SymbolTableEntry *symbol_table_lookup(const char *name, unsigned int scope);
void symbol_table_hide(unsigned int scope);
void symbol_table_print(void);

#endif
