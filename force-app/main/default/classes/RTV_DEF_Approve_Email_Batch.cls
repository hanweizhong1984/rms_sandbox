/**
 * Order被CS审批时，发送邮件给WSL
 */
public class RTV_DEF_Approve_Email_Batch
implements Database.Batchable<SObject>, Database.Stateful {
    /** 参数: orderId */
    public final Set<Id> orderIds;
    
    /** 其它参数：可选发件人别名 */
    public String customSenderName; 
    
    /** 其它参数：order的状态 */
    public String orderStatus = 'Insp Wait Approval';
    
    /** 错误信息 */
    public Set<String> errorMessages = new Set<String>();
    
    /** 构造 */
    public RTV_DEF_Approve_Email_Batch(Set<Id> orderIds) {
        this.orderIds = orderIds;
    }
    
    /** 开始 */
    public Database.QueryLocator start(Database.BatchableContext info){
        // 检索Order
        return Database.getQueryLocator([
            SELECT Id, Name, Ship_To_Outbound_Emails__c, Ship_To__r.Name
            FROM RTV_Order__c 
            WHERE Status__c = :this.orderStatus
            AND Id = :this.orderIds
            AND Ship_To_Outbound_Emails__c != null
        ]);
    }
    
    /** 
     * 执行 
     * (建议每次处理10个订单)
     */
    public void execute(Database.BatchableContext info, List<RTV_Order__c> orders) {
        List<RTV_Order__c> updOrders = new List<RTV_Order__c>();
        
        // 遍历order
        for (RTV_Order__c order: orders) {
            try {
                // 创建email
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setBccSender(false); // 不关联到Bcc
                mail.setUseSignature(false); // 不设置发件人的签名
                
                // email.自定义发件人
                if (this.customSenderName != null) {
                    mail.setSenderDisplayName(this.customSenderName);
                }
                
                // email.收件人
                String toAddrStr = order.Ship_To_Outbound_Emails__c
                    .replace('，', ',')
                    .replace(';', ',')
                    .replace('；', ',')
                    .replace('>', '')
                    .replace('<', '');
                List<String> toAddrs = toAddrStr.split(',');
                mail.setToAddresses(toAddrs);
                
                // email.内容
                addEmailBody(mail, order);
                
                // email.附件
                addEmailAttach(mail, order);
                
                // 发送
                Messaging.reserveSingleEmailCapacity(toAddrs.size()); //保留电子邮件容量, 确保不会超过每日电子邮件限制
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail}, true);
                
                // 检查结果
                for (Messaging.SendEmailResult res: results) {
                    if (res.isSuccess() == false) {
                        throw new RMS_CommonUtil.RMSException(res.getErrors()[0].getMessage());
                    }
                }
                
                // Order中更新结果
                RTV_Order__c updO = new RTV_Order__c();
                updO.Id = order.Id;
                updO.Ship_To_Out_Emails_Status__c = 'Sent';
                updOrders.add(updO);
            } 
            catch (Exception err) {
                this.errorMessages.add('邮件发送失败：订单编号='+order.name+', 错误信息='+err.getMessage());
                
                // Order中更新结果
                RTV_Order__c updO = new RTV_Order__c();
                updO.Id = order.Id;
                updO.Ship_To_Out_Emails_Status__c = 'Failed';
                updOrders.add(updO);
            }
        }
        update updOrders;
    }
    
    /** Email的附件里 */
    public void addEmailAttach(Messaging.SingleEmailMessage mail, RTV_Order__c order) {
        // 获取该order的report导出结果
        ApexPages.PageReference reportPage = new ApexPages.PageReference(
            '/apex/RTV_Defective_Report_Inspect?orderId='+order.Id
        );
        Blob reportBlob;
        if (Test.isRunningTest() == false) {
            reportBlob = reportPage.getcontent();
        }
        
        // 添加report导出结果到email附件
        Messaging.EmailFileAttachment  att = new Messaging.EmailFileAttachment();
        att.setFileName('质检结果.xls');
        att.setBody(reportBlob);
        att.setContentType('application/vnd.ms-excel');
        
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{att});
    }
    
    /** 设置邮件内容 */
    public void addEmailBody(Messaging.SingleEmailMessage mail, RTV_Order__c order) {
        mail.setSubject(
            '[RMS-Confirmed] 退残订单'+order.Name+'，'+order.Ship_To__r.Name+'，质检结果已完成，请查看并核实报告');
        
        mail.setPlainTextBody(
            'HI, ALL\r\n'+
            '\r\n'+
            '退残订单'+order.Name+'质检结果已完成，请尽快核准质检结果。\r\n'+
            '\r\n'+
            '订单名称：'+order.Name+'\r\n'+
            '客户名称：'+order.Ship_To__r.Name+'\r\n'+
            '详细信息请参考附件。\r\n'+
            '注：核准审批即将失效，如有问题请尽快操作。\r\n'+
            '\r\n'+
            '特此通知。\r\n'+
            'Best regards\r\n'+
            '\r\n'+
            'Converse - RMS 系统运维\r\n'
        );
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext ctx) {
        // 记录Batch执行的错误信息
        if (this.errorMessages.size() != 0) {
            RTV_Log__c log = new RTV_Log__c();
            log.Name = 'RTV_DEF_Approve_Email_Batch';
            log.Batch_Job_Id__c = ctx.getJobId();
            log.Errors__c = String.join(new List<String>(this.errorMessages), '\r\n');
            insert log;
        }
    }
}