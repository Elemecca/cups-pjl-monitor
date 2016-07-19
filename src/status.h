#ifndef _STATUS_H
#define _STATUS_H

#include <stdint.h>


typedef struct {
    int_fast32_t integer;
    double fraction;
} number_t;

#define STR_BUFFER_LEN 8192
typedef struct {
    size_t count;
    uint8_t *buffer;
} string_t;


struct status_device {
    int_fast32_t status;
    string_t display;
    int online;
};

struct status_job {
    int_fast32_t id;
    string_t name;
    int_fast32_t pages;
};



enum status_report_type {
    STYPE_NONE = 0,
    STYPE_DEVICE,
    STYPE_JOB_START,
    STYPE_JOB_END,
    STYPE_PAGES,
    STYPE_ECHO
};

typedef struct status_report {
    enum status_report_type type;
    union {
        struct status_device device;
        struct status_job job;
        int_fast32_t pages;
        string_t echo;
    };
} status_report_t;



void yyerror (status_report_t *status, const char const *msg);

#endif
