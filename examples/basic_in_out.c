#include <stdlib.h>
#include <stdio.h>

#include "tico.h"


struct data {
    int value;
    const char *ident;
};


static tico_t *coro(void *ud, tico_t *co)
{
    struct data *vals = ud;

    tico_t *main_co;
    int status = tico_switch(co, NULL, &main_co);
    if (status == -1) {
        printf("coro error: initial switch\n");
        exit(1);
    } else if (status != 0) {
        printf("coro error: main ended\n");
        exit(1);
    }

    do {
        printf("coro loop: %d called by %s\n", vals->value, vals->ident);

        vals->value *= 100;
        vals->ident = "coro loop";
        status = tico_switch(co, main_co, &main_co);
        if (status == -1) {
            printf("coro error: loop switch\n");
            exit(1);
        } else if (status != 0) {
            printf("coro error: main ended (loop)\n");
            exit(1);
        }
    } while (vals->value != 0);

    printf("coro end: %d called by %s\n", vals->value, vals->ident);
    return main_co;
}


int main()
{
    struct data vals = { 0, NULL };
    void *coro_stack = malloc(4096);

    tico_t *co;
    int status = tico_init(coro_stack, 4096, coro, &vals, &co);
    if (status == -1) {
        printf("main error: init returned error\n");
        return 1;
    } else if (status != 0) {
        printf("main error: coro returned\n");
        return 1;
    }

    printf("main 0\n");

    vals.value = 1;
    vals.ident = "main 0";
    if ((status = tico_switch(NULL, co, &co)) != 0) {
        printf("main error: switch returned %d\n", status);
        return 1;
    }
    printf("main 1: %d called by %s\n", vals.value, vals.ident);

    vals.value = 2;
    vals.ident = "main 1";
    if ((status = tico_switch(NULL, co, &co)) != 0) {
        printf("main error: switch returned %d\n", status);
        return 1;
    }
    printf("main 2: %d called by %s\n", vals.value, vals.ident);

    vals.value = 0;
    vals.ident = "main 2";
    if ((status = tico_switch(NULL, co, &co)) != 1) {
        printf("main error: switch returned %d\n", status);
        return 1;
    }

    free(coro_stack);
    printf("ok\n");
    return 0;
}
