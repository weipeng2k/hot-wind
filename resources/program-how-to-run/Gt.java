import java.io.BufferedReader;
import java.io.InputStreamReader;

/**
 * @author weipeng2k 2022年05月17日 下午19:00:44
 */
public class Gt {

    public static void main(String[] args) throws Exception {
        int a, b;
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));

        System.out.println("输入第一个数：");
        a = Integer.parseInt(reader.readLine());

        System.out.println("输入第二个数：");
        b = Integer.parseInt(reader.readLine());

        int x = gt(a, b);
        System.out.format("较大的数是：%d\n", x);
    }

    public static int gt(int a, int b) {
        return a > b ? a : b;
    }

}
