@IsTest(isParallel=true)
public class Test_RTV_DEF_SellingPrice_All {
    @isTest
    public static void test() {
        RTV_DEF_SellingPrice_All.lieToTest();
        RTV_DEF_UploadSellingPrice_All_Batch.lieToTest();
    }
}