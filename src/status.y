%{
#include <stdint.h>
#include <string.h>
#include "status.h"
%}

/* version constraints:
 *   2.3b  push-parsing mode
 *   2.3b  %code declaration
 *   2.5   lookahead correction (LAC)
 *   2.5   named references
 * also, Ubuntu precise and Debian wheezy only have 2.5
 */
%require "2.5"

/* use push mode because we need to be fully non-blocking */
%define api.push-pull push

/* generate a reeentrant parser
 * non-reentrant push parsers are ugly
 * we can't use `full`, that was added in 2.7
 */
%define api.pure true

/* produce good (better, at least) error messages */
%error-verbose
%define parse.lac full



/* add an out parameter to return parsed reports */
%parse-param {status_report_t *result}


%union {
    uint8_t character;
    string_t string;

    int_fast32_t integer;
    /*
    double fraction;
    number_t number;
    */

    int boolean;

    status_report_t *report;
}

%destructor { free( $$.buffer ); } <string>
%destructor { free( $$ ); } <report>

%code provides {
#define NEW_REPORT(var, stype) \
    var = malloc( sizeof(status_report_t) ); \
    if (NULL == var) { \
        yyerror( result, "error allocating report object" ); \
        YYABORT; \
    } \
    memset( var, 0, sizeof(status_report_t) ); \
    var->type = (stype);
}


/* Roman-8 characters that don't map to ASCII */
%token <character> TOK_CHAR

/* control characters not used in grammar rules */
%token <character> TOK_CTL

/* declare type for all character tokens used */
%type <character> '\t' '\n' '\f' '\r'
%type <character> ' ' '!' '"' '#' '$' '%' '&' '(' ')' '*' '+' ',' '-'
%type <character> '.' '/' '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' ':'
%type <character> ';' '<' '=' '>' '?' '@' 'A' 'B' 'C' 'D' 'E' 'F' 'G'
%type <character> 'H' 'I' 'J' 'K' 'L' 'M' 'N' 'O' 'P' 'Q' 'R' 'S' 'T'
%type <character> 'U' 'V' 'W' 'X' 'Y' 'Z' '[' ']' '^' '_' '`' 'a' 'b'
%type <character> 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o'
%type <character> 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z' '{' '|'
%type <character> '}' '~' '\'' '\\'


%start reports

%type <character> c_alpha_uc c_alpha_lc c_alpha c_digit c_alnum
%type <character> c_sym_noquot c_sym c_printable WS

%type <integer> num_natural num_digit
/*
%type <number> number
%type <integer> num_int num_sign num_natural
%type <fraction> num_decimal num_fraction
*/

%type <string> string str_chars words
%type <character> str_char words_char
%type <boolean> boolean;


%type <report> report command echo
%type <report> ustatus ustatus_var info info_cat
%type <report> dev_vars job_vars page_val;

%%

empty: /* empty */;

/* letter pseudo-terminals for case-insensitivity */
A: 'A' | 'a';
B: 'B' | 'b';
C: 'C' | 'c';
D: 'D' | 'd';
E: 'E' | 'e';
F: 'F' | 'f';
G: 'G' | 'g';
H: 'H' | 'h';
I: 'I' | 'i';
J: 'J' | 'j';
/*K: 'K' | 'k';*/
L: 'L' | 'l';
M: 'M' | 'm';
N: 'N' | 'n';
O: 'O' | 'o';
P: 'P' | 'p';
/*Q: 'Q' | 'q';*/
R: 'R' | 'r';
S: 'S' | 's';
T: 'T' | 't';
U: 'U' | 'u';
V: 'V' | 'v';
/*W: 'W' | 'w';*/
/*X: 'X' | 'x';*/
Y: 'Y' | 'y';
/*Z: 'Z' | 'z';*/




FF: '\f';
LF: '\n' | '\r' '\n'

WS: ' ' | '\t';
ws: WS | ws WS;
ows: empty | ws;



c_alpha_uc: 'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'G' | 'H' | 'I' | 'J'
          | 'K' | 'L' | 'M' | 'N' | 'O' | 'P' | 'Q' | 'R' | 'S' | 'T'
          | 'U' | 'V' | 'W' | 'X' | 'Y' | 'Z'
          ;

c_alpha_lc: 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'g' | 'h' | 'i' | 'j'
          | 'k' | 'l' | 'm' | 'n' | 'o' | 'p' | 'q' | 'r' | 's' | 't'
          | 'u' | 'v' | 'w' | 'x' | 'y' | 'z'
          ;

c_alpha: c_alpha_uc | c_alpha_lc;

c_digit: '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9';

c_alnum: c_alpha | c_digit;

c_sym_noquot: '!' | '#' | '$' | '%' | '&' | '\''
            | '(' | ')' | '*' | '+' | ',' | '-' | '.' | '/'
            | ':' | ';' | '<' | '=' | '>' | '?' | '@' | '[' | '\\'
            | ']' | '^' | '_' | '`' | '{' | '|' | '}' | '~'
            ;

c_sym: c_sym_noquot | '"';

c_printable: c_alnum | c_sym | TOK_CHAR;


/* keyword pseudo-terminals */
PJL:        '@' 'P' 'J' 'L';
CODE:       C O D E;
DEVICE:     D E V I C E;
DISPLAY:    D I S P L A Y;
ECHO:       E C H O;
END:        E N D;
FALSE:      F A L S E;
ID:         I D;
INFO:       I N F O;
JOB:        J O B;
NAME:       N A M E;
ONLINE:     O N L I N E;
PAGE:       P A G E;
PAGES:      P A G E S;
START:      S T A R T;
STATUS:     S T A T U S;
TIMED:      T I M E D;
TRUE:       T R U E;
USTATUS:    U S T A T U S;


/*
number: num_int num_decimal {
            $$.integer  = $1;
            $$.fraction = $2;
        }
    ;

num_int: num_sign num_natural { $$ = $1 * $2; };

num_sign:
      empty   { $$ =  1; }
    | '+'           { $$ =  1; }
    | '-'           { $$ = -1; }
    ;
*/

num_natural:
      num_digit { $$ = $1; }
    | num_natural num_digit {
            if ($1 > (INT_FAST32_MAX - 10) / 10) {
                yyerror( result, "integer overflow in number literal" );
                YYERROR;
            } else {
                $$ = $1 * 10 + $2;
            }
        }
    ;

/*
num_decimal:
      empty       { $$ = 0; }
    | '.'               { $$ = 0; }
    | '.' num_fraction  { $$ = $2; }
    ;

 * must be right-recursive to calculate properly
 * since the least-significant digit is on the right
 *
num_fraction:
      num_digit { $$ = $1 / 10; }
    | num_digit num_fraction {
            $$ = ((double)$1) / 10 + $2 / 10;
        }
    ;
*/

num_digit: c_digit { $$ = $1 - '0'; };



string:
    '"' str_chars '"' {
            $$.buffer = $2.buffer;
            $$.count  = $2.count;
        }
    ;

str_chars:
    empty {
            $$.count = 0;

            $$.buffer = malloc( STR_BUFFER_LEN );
            if (NULL == $$.buffer) {
                yyerror( result, "error allocating string buffer" );
                YYABORT;
            }

            memset( $$.buffer, 0, STR_BUFFER_LEN );
        }
    | str_chars str_char {
            if ($1.count >= STR_BUFFER_LEN) {
                yyerror( result, "buffer overflow in string literal" );
                YYERROR;
            } else {
                $$.buffer = $1.buffer;
                $$.count  = $1.count;
                $$.buffer[ $$.count++ ] = $2;
            }
        }
    ;

str_char: c_alnum | c_sym_noquot | WS | TOK_CHAR;



words:
     c_printable {
            $$.count = 0;

            $$.buffer = malloc( STR_BUFFER_LEN );
            if (NULL == $$.buffer) {
                yyerror( result, "error allocating string buffer" );
                YYABORT;
            }

            memset( $$.buffer, 0, STR_BUFFER_LEN );
        }
    | words words_char {
            if ($1.count >= STR_BUFFER_LEN) {
                yyerror( result, "buffer overflow in string literal" );
                YYERROR;
            } else {
                $$.buffer = $1.buffer;
                $$.count  = $1.count;
                $$.buffer[ $$.count++ ] = $2;
            }
        }
    ;

words_char: c_printable | WS;



boolean:
      TRUE  { $$ = 1; }
    | FALSE { $$ = 0; }
    ;



reports:
      empty
    | reports report {
            memcpy( result, $2, sizeof(status_report_t) );
            free( $2 );
            YYACCEPT;
        }
    | reports error FF /* on a syntax error, discard until the next FF */
    ;

report: PJL ws command FF { $$ = $3; };
command: ustatus | info | echo;

ustatus: USTATUS ws ustatus_var { $$ = $3; };
ustatus_var:
      DEVICE ows LF dev_vars { $$ = $4; }
    | TIMED  ows LF dev_vars { $$ = $4; }
    | JOB    ows LF job_vars { $$ = $4; }
    | PAGE   ows LF page_val { $$ = $4; }
    ;


info: INFO ws info_cat { $$ = $3; };
info_cat:
      STATUS ows LF dev_vars { $$ = $4; }
    ;

echo: ECHO ows words LF {
            NEW_REPORT( $$, STYPE_ECHO )
            $$->echo = $3;
        }
    ;



dev_vars:
      empty { NEW_REPORT( $$, STYPE_DEVICE ) }
    | dev_vars CODE '=' num_natural LF
        { $$ = $1; $$->device.status = $4; }
    | dev_vars DISPLAY '=' string LF
        { $$ = $1; $$->device.display = $4; }
    | dev_vars ONLINE '=' boolean LF
        { $$ = $1; $$->device.online  = $4; }
    | dev_vars error LF /* on a syntax error, discard until the next LF */
    ;


job_vars:
      START LF { NEW_REPORT( $$, STYPE_JOB_START ) }
    | END   LF { NEW_REPORT( $$, STYPE_JOB_END ) }
    | job_vars ID '=' num_natural LF
        { $$ = $1; $$->job.id = $4; }
    | job_vars NAME '=' string LF
        { $$ = $1; $$->job.name = $4; }
    | job_vars PAGES '=' num_natural LF
        { $$ = $1; $$->job.pages = $4; }
    | job_vars error LF /* on a syntax error, discard until the next LF */
    ;

page_val: num_natural LF {
            NEW_REPORT( $$, STYPE_PAGES )
            $$->pages = $1;
        }
    ;
