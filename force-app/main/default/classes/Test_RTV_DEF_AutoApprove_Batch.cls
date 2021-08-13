@IsTest
public  class Test_RTV_DEF_AutoApprove_Batch {
    @isTest
    public static void test() {
        // 开始
        RTV_DEF_AutoApprove_Batch batch = new RTV_DEF_AutoApprove_Batch();
        batch.errorMessages.add('xxxx');
        
        // 定时任务
        try {batch.execute(null);} catch (Exception err) {}
        
        // batch.start
        Test.StartTest();
        Database.executeBatch(batch, 1);
        Test.StopTest();
        
        // batch.execute
        try {
            // 假数据
            List<ProcessInstance> prolist = new List<ProcessInstance>();
            ProcessInstance process = new ProcessInstance();
            prolist.add(process);
            
            batch.execute(null, prolist);
        } catch (Exception err) {}
        
        batch.approveAction(new ProcessInstanceHistory());
    }
}