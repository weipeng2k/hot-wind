#include <stdio.h>

int gt(int a, int b);

int main() {
    int a, b;
    
    printf("输入第一个数：");
    scanf("%d", &a);
    printf("输入第二个数：");
    scanf("%d", &b);

    printf("较大的数是：%d\n", gt(a, b));

    return 0;
}

int gt(int a, int b) {
    return a > b ? a : b;
}