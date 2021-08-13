/** 每天删除一些临时的记录，节省储存空间 */
global class RTV_Sch_DeleteTemporaryRecord implements Schedulable {
    /** 执行定时任务 */
    global void execute(SchedulableContext sc){
        // 删除log
        delete [SELECT Id FROM RTV_Log__c];
    }
}