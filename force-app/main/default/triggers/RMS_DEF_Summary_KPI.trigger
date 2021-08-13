trigger RMS_DEF_Summary_KPI on RTV_Order__c (before update,after update) {
    //DEF Summary ID
    Id summaryId = null;
    Id delsummaryId = null;
    Id ispsummaryId = null;
    Id wslsummaryId = null;
    Id cssummaryId = null;
    Id inbsummaryId = null;
    for(RTV_Order__c order:Trigger.new)
    {
        RTV_Order__c oldOrder = Trigger.oldMap.get(order.id);
        if(Trigger.isBefore)
        {
            if(order.Status__c == 'POST to LF' && oldOrder.Status__c =='Ready' && order.RTV_DEF_Summary__c != null)
            {
                summaryId = order.RTV_DEF_Summary__c;
            }
            if(order.Status__c == 'Delivered' && oldOrder.Status__c =='POST to LF' && order.RTV_DEF_Summary__c != null)
            {
                delsummaryId = order.RTV_DEF_Summary__c;
            }
            if(order.Status__c == 'Inspected' && oldOrder.Status__c =='Delivered' && order.RTV_DEF_Summary__c != null)
            {
                ispsummaryId = order.RTV_DEF_Summary__c;
            }
            if(order.Status__c == 'Inbound' && oldOrder.Status__c =='Insp Confirmed' && order.RTV_DEF_Summary__c != null)
            {
                inbsummaryId = order.RTV_DEF_Summary__c;
            }
        }
        if(Trigger.isAfter)
        {
            if(order.Status__c == 'Insp Confirmed' && oldOrder.Status__c =='Insp Wait Approval' && order.RTV_DEF_Summary__c != null)
            {
                wslsummaryId = order.RTV_DEF_Summary__c;
            }
            if(order.Insp_CS_Approve_Time__c != null && oldOrder.Insp_CS_Approve_Time__c == null && order.RTV_DEF_Summary__c != null)
            {
                cssummaryId = order.RTV_DEF_Summary__c;
            }
        }
    }
    /**
     * 获取Summary下第一个Order开始时间
     */
    if(summaryId!=null)
    { 

        List<RTV_Order__c> orderList = [SELECT ID,Name,RTV_DEF_Summary__c 
                                        FROM RTV_Order__c 
                                        WHERE RTV_DEF_Summary__c = :summaryId 
                                        AND (
                                            Status__c = 'POST to LF' 
                                            OR Status__c ='Delivered'
                                            OR Status__c ='Inspected' 
                                            OR Status__c = 'Insp Wait Approval'
                                            OR Status__c = 'Insp Confirmed'
                                            OR Status__c = 'Inbound'
                                            )
                                        ];

        if(orderList.size() == 0)
        {
            RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
            summary.id = this.summaryId;
            summary.Date_Of_Post_To_LF__c = Date.today();
            update summary;
        }
    }
    /**
     * 获取LF提货时间
     */
    if(delsummaryId!=null)
    {
        List<RTV_Order__c> orderList = [SELECT ID,Name,RTV_DEF_Summary__c 
                                        FROM RTV_Order__c 
                                        WHERE RTV_DEF_Summary__c = :delsummaryId 
                                        AND (
                                            Status__c = 'Delivered' 
                                            OR Status__c ='Inspected' 
                                            OR Status__c = 'Insp Wait Approval'
                                            OR Status__c = 'Insp Confirmed'
                                            OR Status__c = 'Inbound'
                                            )
                                        ];
        if(orderList.size() == 0)
        {
            RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
            summary.id = this.delsummaryId;
            summary.Date_Of_Delivered__c = Date.today();
            update summary;
        }
    }
    /**
     * 获取LF质检日期
     */
    if(ispsummaryId!=null)
    {
        List<RTV_Order__c> orderList = [SELECT ID,Name,RTV_DEF_Summary__c 
                                        FROM RTV_Order__c 
                                        WHERE RTV_DEF_Summary__c = :ispsummaryId 
                                        AND (
                                            Status__c = 'Inspected' 
                                            OR Status__c = 'Insp Wait Approval'
                                            OR Status__c = 'Insp Confirmed'
                                            OR Status__c = 'Inbound'
                                            )
                                        ];

        if(orderList.size() == 0)
        {
            RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
            summary.id = this.ispsummaryId;
            summary.Date_Of_Inspected__c = Date.today();
            update summary;
        }
    }
    /**
     * 获取CS Confirm日期
     */
    if(cssummaryId!=null)
    {
        RTV_Order__c order = [SELECT ID,Name,RTV_DEF_Summary__c ,Insp_CS_Approve_Time__c
                                        FROM RTV_Order__c 
                                        WHERE RTV_DEF_Summary__c = :cssummaryId 
                                        AND Insp_CS_Approve_Time__c != null
                                        ORDER BY Insp_CS_Approve_Time__c
                                        Limit 1
                                        ];
        if(order != null)
        {
            RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
            summary.id = this.cssummaryId;
            summary.Date_Of_CS_Confirm__c = order.Insp_CS_Approve_Time__c.date();
            update summary;
        }
    }
    /**
     * 获取WSL Confirm日期
     */
    if(wslsummaryId!=null)
    {
        List<RTV_Order__c> orderList = [SELECT ID,Name,RTV_DEF_Summary__c 
                                        FROM RTV_Order__c 
                                        WHERE RTV_DEF_Summary__c = :wslsummaryId 
                                        AND (
                                            Status__c = 'Ready' 
                                            OR Status__c = 'POST to LF'
                                            OR Status__c = 'Inspected'
                                            OR Status__c = 'Delivered'
                                            OR Status__c = 'Insp Wait Approval'
                                            )
                                        ];

        if(orderList.size() == 0)
        {
            RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
            summary.id = this.wslsummaryId;
            summary.Date_Of_WSL_Confirm__c = Date.today();
            update summary;
        }
    }
    /**
     * 获取Inbound日期
     */
    if(inbsummaryId!=null)
    {
        RTV_DEF_Summary__c summary  = new RTV_DEF_Summary__c();
        summary.id = this.inbsummaryId;
        summary.Date_Of_Inbound__c = Date.today();
        update summary;
    }
}