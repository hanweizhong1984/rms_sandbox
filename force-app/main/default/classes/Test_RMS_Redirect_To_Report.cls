@IsTest(isParallel=true)
public class Test_RMS_Redirect_To_Report {
    @isTest
    public static void test() {
        try {
            Apexpages.currentPage().getParameters().put('reportName', 'xxxxxxx');
            Apexpages.currentPage().getParameters().put('fv0', 'xxx');
            new RMS_Redirect_To_Report().redirect();
        } catch(Exception err) {
        }
    }
}