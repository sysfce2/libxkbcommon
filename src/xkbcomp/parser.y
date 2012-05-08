/************************************************************
 Copyright (c) 1994 by Silicon Graphics Computer Systems, Inc.

 Permission to use, copy, modify, and distribute this
 software and its documentation for any purpose and without
 fee is hereby granted, provided that the above copyright
 notice appear in all copies and that both that copyright
 notice and this permission notice appear in supporting
 documentation, and that the name of Silicon Graphics not be
 used in advertising or publicity pertaining to distribution
 of the software without specific prior written permission.
 Silicon Graphics makes no representation about the suitability
 of this software for any purpose. It is provided "as is"
 without any express or implied warranty.

 SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
 SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
 GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
 DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
 OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
 THE USE OR PERFORMANCE OF THIS SOFTWARE.

 ********************************************************/

%{
#include "xkbcomp-priv.h"
#include "parseutils.h"

extern int yylex(union YYSTYPE *val, struct YYLTYPE *loc, void *scanner);

#define scanner param->scanner
%}

%define		api.pure
%locations
%lex-param	{ void *scanner }
%parse-param	{ struct parser_param *param }

%token
	END_OF_FILE	0
	ERROR_TOK	255
	XKB_KEYMAP	1
	XKB_KEYCODES	2
	XKB_TYPES	3
	XKB_SYMBOLS	4
	XKB_COMPATMAP	5
	XKB_GEOMETRY	6
	XKB_SEMANTICS	7
	XKB_LAYOUT	8
	INCLUDE		10
	OVERRIDE	11
	AUGMENT		12
	REPLACE		13
	ALTERNATE	14
	VIRTUAL_MODS	20
	TYPE		21
	INTERPRET	22
	ACTION_TOK	23
	KEY		24
	ALIAS		25
	GROUP		26
	MODIFIER_MAP	27
	INDICATOR	28
	SHAPE		29
	KEYS		30
	ROW		31
	SECTION		32
	OVERLAY		33
	TEXT		34
	OUTLINE		35
	SOLID		36
	LOGO		37
	VIRTUAL		38
	EQUALS		40
	PLUS		41
	MINUS		42
	DIVIDE		43
	TIMES		44
	OBRACE		45
	CBRACE		46
	OPAREN		47
	CPAREN		48
	OBRACKET	49
	CBRACKET	50
	DOT		51
	COMMA		52
	SEMI		53
	EXCLAM		54
	INVERT		55
	STRING		60
	INTEGER		61
	FLOAT		62
	IDENT		63
	KEYNAME		64
	PARTIAL		70
	DEFAULT		71
	HIDDEN		72
	ALPHANUMERIC_KEYS	73
	MODIFIER_KEYS		74
	KEYPAD_KEYS		75
	FUNCTION_KEYS		76
	ALTERNATE_GROUP		77

%right	EQUALS
%left	PLUS MINUS
%left	TIMES DIVIDE
%left	EXCLAM INVERT
%left	OPAREN
%start	XkbFile
%union	{
	int		 ival;
	unsigned	 uval;
	int64_t		 num;
	char		*str;
	xkb_atom_t	sval;
	ParseCommon	*any;
	ExprDef		*expr;
	VarDef		*var;
	VModDef		*vmod;
	InterpDef	*interp;
	KeyTypeDef	*keyType;
	SymbolsDef	*syms;
	ModMapDef	*modMask;
	GroupCompatDef	*groupCompat;
	IndicatorMapDef	*ledMap;
	IndicatorNameDef *ledName;
	KeycodeDef	*keyName;
	KeyAliasDef	*keyAlias;
        void            *geom;
	XkbFile		*file;
}
%type <num>     INTEGER FLOAT
%type <str>     IDENT KEYNAME STRING
%type <ival>	Number Integer Float SignedNumber
%type <uval>	XkbCompositeType FileType MergeMode OptMergeMode
%type <uval>	DoodadType Flag Flags OptFlags KeyCode
%type <str>	KeyName MapName OptMapName KeySym
%type <sval>	FieldSpec Ident Element String
%type <any>	DeclList Decl
%type <expr>	OptExprList ExprList Expr Term Lhs Terminal ArrayInit KeySyms
%type <expr>	OptKeySymList KeySymList Action ActionList Coord CoordList
%type <var>	VarDecl VarDeclList SymbolsBody SymbolsVarDecl
%type <vmod>	VModDecl VModDefList VModDef
%type <interp>	InterpretDecl InterpretMatch
%type <keyType>	KeyTypeDecl
%type <syms>	SymbolsDecl
%type <modMask>	ModMapDecl
%type <groupCompat> GroupCompatDecl
%type <ledMap>	IndicatorMapDecl
%type <ledName>	IndicatorNameDecl
%type <keyName>	KeyNameDecl
%type <keyAlias> KeyAliasDecl
%type <geom>	ShapeDecl SectionDecl SectionBody SectionBodyItem RowBody RowBodyItem
%type <geom>    Keys Key OverlayDecl OverlayKeyList OverlayKey OutlineList OutlineInList
%type <geom>    DoodadDecl
%type <file>	XkbFile XkbMapConfigList XkbMapConfig XkbConfig
%type <file>	XkbCompositeMap XkbCompMapList
%%
XkbFile		:	XkbCompMapList
			{ $$= param->rtrn= $1; }
		|	XkbMapConfigList
			{ $$= param->rtrn= $1;  }
		|	XkbConfig
			{ $$= param->rtrn= $1; }
		;

XkbCompMapList	:	XkbCompMapList XkbCompositeMap
			{ $$= (XkbFile *)AppendStmt(&$1->common,&$2->common); }
		|	XkbCompositeMap
			{ $$= $1; }
		;

XkbCompositeMap	:	OptFlags XkbCompositeType OptMapName OBRACE
			    XkbMapConfigList
			CBRACE SEMI
			{ $$= CreateXKBFile($2,$3,&$5->common,$1); }
		;

XkbCompositeType:	XKB_KEYMAP	{ $$= XkmKeymapFile; }
		|	XKB_SEMANTICS	{ $$= XkmSemanticsFile; }
		|	XKB_LAYOUT	{ $$= XkmLayoutFile; }
		;

XkbMapConfigList :	XkbMapConfigList XkbMapConfig
			{
                            if (!$2)
                                $$= $1;
                            else
                                $$= (XkbFile *)AppendStmt(&$1->common,&$2->common);
                        }
		|	XkbMapConfig
			{ $$= $1; }
		;

XkbMapConfig	:	OptFlags FileType OptMapName OBRACE
			    DeclList
			CBRACE SEMI
			{
                            if ($2 == XkmGeometryIndex)
                            {
                                free($3);
                                FreeStmt($5);
                                $$= NULL;
                            }
                            else
                            {
                                $$= CreateXKBFile($2,$3,$5,$1);
                            }
                        }
		;

XkbConfig	:	OptFlags FileType OptMapName DeclList
			{
                            if ($2 == XkmGeometryIndex)
                            {
                                free($3);
                                FreeStmt($4);
                                $$= NULL;
                            }
                            else
                            {
                                $$= CreateXKBFile($2,$3,$4,$1);
                            }
                        }
		;


FileType	:	XKB_KEYCODES		{ $$= XkmKeyNamesIndex; }
		|	XKB_TYPES		{ $$= XkmTypesIndex; }
		|	XKB_COMPATMAP		{ $$= XkmCompatMapIndex; }
		|	XKB_SYMBOLS		{ $$= XkmSymbolsIndex; }
		|	XKB_GEOMETRY		{ $$= XkmGeometryIndex; }
		;

OptFlags	:	Flags			{ $$= $1; }
		|				{ $$= 0; }
		;

Flags		:	Flags Flag		{ $$= (($1)|($2)); }
		|	Flag			{ $$= $1; }
		;

Flag		:	PARTIAL			{ $$= XkbLC_Partial; }
		|	DEFAULT			{ $$= XkbLC_Default; }
		|	HIDDEN			{ $$= XkbLC_Hidden; }
		|	ALPHANUMERIC_KEYS	{ $$= XkbLC_AlphanumericKeys; }
		|	MODIFIER_KEYS		{ $$= XkbLC_ModifierKeys; }
		|	KEYPAD_KEYS		{ $$= XkbLC_KeypadKeys; }
		|	FUNCTION_KEYS		{ $$= XkbLC_FunctionKeys; }
		|	ALTERNATE_GROUP		{ $$= XkbLC_AlternateGroup; }
		;

DeclList	:	DeclList Decl
			{ $$= AppendStmt($1,$2); }
		|	{ $$= NULL; }
		;

Decl		:	OptMergeMode VarDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode VModDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode InterpretDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode KeyNameDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode KeyAliasDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode KeyTypeDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode SymbolsDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode ModMapDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode GroupCompatDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode IndicatorMapDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode IndicatorNameDecl
			{
			    $2->merge= StmtSetMerge(&$2->common,$1,&@1,scanner);
			    $$= &$2->common;
			}
		|	OptMergeMode ShapeDecl
			{
			}
		|	OptMergeMode SectionDecl
			{
			}
		|	OptMergeMode DoodadDecl
			{
			}
		|	MergeMode STRING
			{
			    if ($1==MergeAltForm) {
				yyerror(&@1, scanner,
                                        "cannot use 'alternate' to include other maps");
				$$= &IncludeCreate($2,MergeDefault)->common;
			    }
			    else {
				$$= &IncludeCreate($2,$1)->common;
			    }
                            free($2);
                        }
		;

VarDecl		:	Lhs EQUALS Expr SEMI
			{ $$= VarCreate($1,$3); }
		|	Ident SEMI
			{ $$= BoolVarCreate($1,1); }
		|	EXCLAM Ident SEMI
			{ $$= BoolVarCreate($2,0); }
		;

KeyNameDecl	:	KeyName EQUALS KeyCode SEMI
                        {
			    KeycodeDef *def;

			    def= KeycodeCreate($1,$3);
			    free($1);
			    $$= def;
			}
		;

KeyAliasDecl	:	ALIAS KeyName EQUALS KeyName SEMI
			{
			    KeyAliasDef	*def;
			    def= KeyAliasCreate($2,$4);
			    free($2);
			    free($4);
			    $$= def;
			}
		;

VModDecl	:	VIRTUAL_MODS VModDefList SEMI
			{ $$= $2; }
		;

VModDefList	:	VModDefList COMMA VModDef
			{ $$= (VModDef *)AppendStmt(&$1->common,&$3->common); }
		|	VModDef
			{ $$= $1; }
		;

VModDef		:	Ident
			{ $$= VModCreate($1,NULL); }
		|	Ident EQUALS Expr
			{ $$= VModCreate($1,$3); }
		;

InterpretDecl	:	INTERPRET InterpretMatch OBRACE
			    VarDeclList
			CBRACE SEMI
			{
			    $2->def= $4;
			    $$= $2;
			}
		;

InterpretMatch	:	KeySym PLUS Expr	
			{ $$= InterpCreate($1, $3); }
		|	KeySym			
			{ $$= InterpCreate($1, NULL); }
		;

VarDeclList	:	VarDeclList VarDecl
			{ $$= (VarDef *)AppendStmt(&$1->common,&$2->common); }
		|	VarDecl
			{ $$= $1; }
		;

KeyTypeDecl	:	TYPE String OBRACE
			    VarDeclList
			CBRACE SEMI
			{ $$= KeyTypeCreate($2,$4); }
		;

SymbolsDecl	:	KEY KeyName OBRACE
			    SymbolsBody
			CBRACE SEMI
			{ $$= SymbolsCreate($2,(ExprDef *)$4); free($2); }
		;

SymbolsBody	:	SymbolsBody COMMA SymbolsVarDecl
			{ $$= (VarDef *)AppendStmt(&$1->common,&$3->common); }
		|	SymbolsVarDecl
			{ $$= $1; }
		|	{ $$= NULL; }
		;

SymbolsVarDecl	:	Lhs EQUALS Expr
			{ $$= VarCreate($1,$3); }
		|	Lhs EQUALS ArrayInit
			{ $$= VarCreate($1,$3); }
		|	Ident
			{ $$= BoolVarCreate($1,1); }
		|	EXCLAM Ident
			{ $$= BoolVarCreate($2,0); }
		|	ArrayInit
			{ $$= VarCreate(NULL,$1); }
		;

ArrayInit	:	OBRACKET OptKeySymList CBRACKET
			{ $$= $2; }
		|	OBRACKET ActionList CBRACKET
			{ $$= ExprCreateUnary(ExprActionList,TypeAction,$2); }
		;

GroupCompatDecl	:	GROUP Integer EQUALS Expr SEMI
			{ $$= GroupCompatCreate($2,$4); }
		;

ModMapDecl	:	MODIFIER_MAP Ident OBRACE ExprList CBRACE SEMI
			{ $$= ModMapCreate($2,$4); }
		;

IndicatorMapDecl:	INDICATOR String OBRACE VarDeclList CBRACE SEMI
			{ $$= IndicatorMapCreate($2,$4); }
		;

IndicatorNameDecl:	INDICATOR Integer EQUALS Expr SEMI
			{ $$= IndicatorNameCreate($2,$4,false); }
		|	VIRTUAL INDICATOR Integer EQUALS Expr SEMI
			{ $$= IndicatorNameCreate($3,$5,true); }
		;

ShapeDecl	:	SHAPE String OBRACE OutlineList CBRACE SEMI
			{ $$= NULL; }
		|	SHAPE String OBRACE CoordList CBRACE SEMI
			{ $$= NULL; }
		;

SectionDecl	:	SECTION String OBRACE SectionBody CBRACE SEMI
			{ $$= NULL; }
		;

SectionBody	:	SectionBody SectionBodyItem
			{ $$= NULL;}
		|	SectionBodyItem
			{ $$= NULL; }
		;

SectionBodyItem	:	ROW OBRACE RowBody CBRACE SEMI
			{ $$= NULL; }
		|	VarDecl
			{ FreeStmt(&$1->common); $$= NULL; }
		|	DoodadDecl
			{ $$= NULL; }
		|	IndicatorMapDecl
			{ FreeStmt(&$1->common); $$= NULL; }
		|	OverlayDecl
			{ $$= NULL; }
		;

RowBody		:	RowBody RowBodyItem
			{ $$= NULL;}
		|	RowBodyItem
			{ $$= NULL; }
		;

RowBodyItem	:	KEYS OBRACE Keys CBRACE SEMI
			{ $$= NULL; }
		|	VarDecl
			{ FreeStmt(&$1->common); $$= NULL; }
		;

Keys		:	Keys COMMA Key
			{ $$= NULL; }
		|	Key
			{ $$= NULL; }
		;

Key		:	KeyName
			{ free($1); $$= NULL; }
		|	OBRACE ExprList CBRACE
			{ FreeStmt(&$2->common); $$= NULL; }
		;

OverlayDecl	:	OVERLAY String OBRACE OverlayKeyList CBRACE SEMI
			{ $$= NULL; }
		;

OverlayKeyList	:	OverlayKeyList COMMA OverlayKey
			{ $$= NULL; }
		|	OverlayKey
			{ $$= NULL; }
		;

OverlayKey	:	KeyName EQUALS KeyName
			{ free($1); free($3); $$= NULL; }
		;

OutlineList	:	OutlineList COMMA OutlineInList
			{ $$= NULL;}
		|	OutlineInList
			{ $$= NULL; }
		;

OutlineInList	:	OBRACE CoordList CBRACE
			{ $$= NULL; }
		|	Ident EQUALS OBRACE CoordList CBRACE
			{ $$= NULL; }
		|	Ident EQUALS Expr
			{ FreeStmt(&$3->common); $$= NULL; }
		;

CoordList	:	CoordList COMMA Coord
			{ $$= NULL; }
		|	Coord
			{ $$= NULL; }
		;

Coord		:	OBRACKET SignedNumber COMMA SignedNumber CBRACKET
			{ $$= NULL; }
		;

DoodadDecl	:	DoodadType String OBRACE VarDeclList CBRACE SEMI
			{ FreeStmt(&$4->common); $$= NULL; }
		;

DoodadType	:	TEXT			{ $$= 0; }
		|	OUTLINE			{ $$= 0; }
		|	SOLID			{ $$= 0; }
		|	LOGO			{ $$= 0; }
		;

FieldSpec	:	Ident			{ $$= $1; }
		|	Element			{ $$= $1; }
		;

Element		:	ACTION_TOK		
			{ $$= xkb_intern_atom("action"); }
		|	INTERPRET
			{ $$= xkb_intern_atom("interpret"); }
		|	TYPE
			{ $$= xkb_intern_atom("type"); }
		|	KEY
			{ $$= xkb_intern_atom("key"); }
		|	GROUP
			{ $$= xkb_intern_atom("group"); }
		|	MODIFIER_MAP
			{$$= xkb_intern_atom("modifier_map");}
		|	INDICATOR
			{ $$= xkb_intern_atom("indicator"); }
		|	SHAPE	
			{ $$= xkb_intern_atom("shape"); }
		|	ROW	
			{ $$= XKB_ATOM_NONE; }
		|	SECTION	
			{ $$= XKB_ATOM_NONE; }
		|	TEXT
			{ $$= XKB_ATOM_NONE; }
		;

OptMergeMode	:	MergeMode		{ $$= $1; }
		|				{ $$= MergeDefault; }
		;

MergeMode	:	INCLUDE			{ $$= MergeDefault; }
		|	AUGMENT			{ $$= MergeAugment; }
		|	OVERRIDE		{ $$= MergeOverride; }
		|	REPLACE			{ $$= MergeReplace; }
		|	ALTERNATE		{ $$= MergeAltForm; }
		;

OptExprList	:	ExprList			{ $$= $1; }
		|				{ $$= NULL; }
		;

ExprList	:	ExprList COMMA Expr
			{ $$= (ExprDef *)AppendStmt(&$1->common,&$3->common); }
		|	Expr
			{ $$= $1; }
		;

Expr		:	Expr DIVIDE Expr
			{ $$= ExprCreateBinary(OpDivide,$1,$3); }
		|	Expr PLUS Expr
			{ $$= ExprCreateBinary(OpAdd,$1,$3); }
		|	Expr MINUS Expr
			{ $$= ExprCreateBinary(OpSubtract,$1,$3); }
		|	Expr TIMES Expr
			{ $$= ExprCreateBinary(OpMultiply,$1,$3); }
		|	Lhs EQUALS Expr
			{ $$= ExprCreateBinary(OpAssign,$1,$3); }
		|	Term
			{ $$= $1; }
		;

Term		:	MINUS Term
			{ $$= ExprCreateUnary(OpNegate,$2->type,$2); }
		|	PLUS Term
			{ $$= ExprCreateUnary(OpUnaryPlus,$2->type,$2); }
		|	EXCLAM Term
			{ $$= ExprCreateUnary(OpNot,TypeBoolean,$2); }
		|	INVERT Term
			{ $$= ExprCreateUnary(OpInvert,$2->type,$2); }
		|	Lhs
			{ $$= $1;  }
		|	FieldSpec OPAREN OptExprList CPAREN %prec OPAREN
			{ $$= ActionCreate($1,$3); }
		|	Terminal
			{ $$= $1;  }
		|	OPAREN Expr CPAREN
			{ $$= $2;  }
		;

ActionList	:	ActionList COMMA Action
			{ $$= (ExprDef *)AppendStmt(&$1->common,&$3->common); }
		|	Action
			{ $$= $1; }
		;

Action		:	FieldSpec OPAREN OptExprList CPAREN
			{ $$= ActionCreate($1,$3); }
		;

Lhs		:	FieldSpec
			{
			    ExprDef *expr;
                            expr= ExprCreate(ExprIdent,TypeUnknown);
                            expr->value.str= $1;
                            $$= expr;
			}
		|	FieldSpec DOT FieldSpec
                        {
                            ExprDef *expr;
                            expr= ExprCreate(ExprFieldRef,TypeUnknown);
                            expr->value.field.element= $1;
                            expr->value.field.field= $3;
                            $$= expr;
			}
		|	FieldSpec OBRACKET Expr CBRACKET
			{
			    ExprDef *expr;
			    expr= ExprCreate(ExprArrayRef,TypeUnknown);
			    expr->value.array.element= XKB_ATOM_NONE;
			    expr->value.array.field= $1;
			    expr->value.array.entry= $3;
			    $$= expr;
			}
		|	FieldSpec DOT FieldSpec OBRACKET Expr CBRACKET
			{
			    ExprDef *expr;
			    expr= ExprCreate(ExprArrayRef,TypeUnknown);
			    expr->value.array.element= $1;
			    expr->value.array.field= $3;
			    expr->value.array.entry= $5;
			    $$= expr;
			}
		;

Terminal	:	String
			{
			    ExprDef *expr;
                            expr= ExprCreate(ExprValue,TypeString);
                            expr->value.str= $1;
                            $$= expr;
			}
		|	Integer
			{
			    ExprDef *expr;
                            expr= ExprCreate(ExprValue,TypeInt);
                            expr->value.ival= $1;
                            $$= expr;
			}
		|	Float
			{
			    $$= NULL;
			}
		|	KeyName
			{
			    ExprDef *expr;
			    expr= ExprCreate(ExprValue,TypeKeyName);
			    memset(expr->value.keyName,0,5);
			    strncpy(expr->value.keyName,$1,4);
			    free($1);
			    $$= expr;
			}
		;

OptKeySymList	:	KeySymList			{ $$= $1; }
		|					{ $$= NULL; }
		;

KeySymList	:	KeySymList COMMA KeySym
			{ $$= AppendKeysymList($1,$3); }
                |       KeySymList COMMA KeySyms
                        { $$= AppendMultiKeysymList($1,$3); }
		|	KeySym
			{ $$= CreateKeysymList($1); }
                |       KeySyms
                        { $$= CreateMultiKeysymList($1); }
		;

KeySyms         :       OBRACE KeySymList CBRACE
                        { $$= $2; }
                ;

KeySym		:	IDENT	{ $$= $1; }
		|	SECTION	{ $$= strdup("section"); }
		|	Integer		
			{
			    if ($1 < 10) {	/* XK_0 .. XK_9 */
				$$= malloc(2);
				$$[0]= $1 + '0';
				$$[1]= '\0';
			    }
			    else {
				$$= malloc(17);
				snprintf($$, 17, "0x%x", $1);
			    }
			}
		;

SignedNumber	:	MINUS Number    { $$= -$2; }
		|	Number              { $$= $1; }
		;

Number		:	FLOAT		{ $$= $1; }
		|	INTEGER		{ $$= $1*XkbGeomPtsPerMM; }
		;

Float		:	FLOAT		{ $$= 0; }
		;

Integer		:	INTEGER		{ $$= $1; }
		;

KeyCode         :       INTEGER         { $$= $1; }
                ;

KeyName		:	KEYNAME		{ $$= $1; }
		;

Ident		:	IDENT	{ $$= xkb_intern_atom($1); free($1); }
		|	DEFAULT { $$= xkb_intern_atom("default"); }
		;

String		:	STRING	{ $$= xkb_intern_atom($1); free($1); }
		;

OptMapName	:	MapName	{ $$= $1; }
		|		{ $$= NULL; }
		;

MapName		:	STRING 	{ $$= $1; }
		;

%%

#undef scanner