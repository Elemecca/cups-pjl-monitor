%{
#include <stdint.h>
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
    uint8_t charval;
}



/* Roman-8 characters that don't map to ASCII */
%token <charval> TOK_CHAR

/* control characters not used in grammar rules */
%token <charval> TOK_CTL



%start reports

%%

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
ows: /* empty */ | ws;



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



number: num_sign c_digit num_digits num_decimal;
num_sign: /* empty */ | '+' | '-';
num_digits: /* empty */ | num_digits c_digit;
num_decimal: /* empty */ | '.' num_digits;

string: '"' str_chars '"';
str_chars: /* empty */ | str_chars str_char;
str_char: c_alnum | c_sym;

boolean: TRUE | FALSE;



reports: report
       | reports report
       | error FF /* on a syntax error, discard until the next FF */
       ;

report: PJL ws command FF;
command: ustatus | info | echo;

ustatus: USTATUS ws ustatus_var;
ustatus_var: ustatus_dev | ustatus_job | ustatus_page | ustatus_timed;
ustatus_dev:   DEVICE ows LF dev_vars;
ustatus_timed: TIMED  ows LF dev_vars;
ustatus_job:   JOB    ows LF job_vars;
ustatus_page:  PAGE   ows LF page_val;


info: INFO ws info_cat;
info_cat: info_status;
info_status: STATUS ows LF dev_vars;

echo: ECHO ows echo_msg LF;
echo_msg: c_printable | echo_msg echo_char;
echo_char: c_printable | WS;


dev_vars: dev_var | dev_vars dev_var;
dev_var: CODE '=' number LF
       | DISPLAY '=' string LF
       | ONLINE '=' boolean LF
       | error LF /* on a syntax error, discard until the next LF */
       ;


job_vars: job_act LF
        | job_vars job_var
        ;
job_act: END | START;
job_var: ID '=' number LF
       | NAME '=' string LF
       | PAGES '=' number LF
       | error LF /* on a syntax error, discard until the next LF */
       ;

page_val: number LF;
