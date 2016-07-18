#ifndef _STATUS_H
#define _STATUS_H


#define STATUS_TYPE_NONE 0

typedef struct status_report {
    int type;
} status_report_t;



void yyerror (status_report_t *status, const char const *msg);

#endif
