// order更新时，重新统计summary
trigger RMS_Order_Total on RTV_Order__c (after insert, after update, after delete) {
    
    Map<Id, RTV_Summary__c> updSummaries = new Map<Id, RTV_Summary__c>();
    
    // order新增时
    if(Trigger.isInsert) {
        for (RTV_Order__c order: Trigger.new) {
            if (order.Return_Summary__c != null) {
                
                RTV_Summary__c updS = new RTV_Summary__c();
                updS.Id = order.Return_Summary__c;
                updS.Application_QTY__c = 0;
                updS.Application_Amount__c = 0;
                updS.Delivery_QTY__c = 0;
                updS.Inspect_QTY_A__c = 0;
                updS.Inspect_QTY_B__c = 0;
                updS.Inspect_QTY_C__c = 0;
                updS.Inspect_QTY_D__c = 0;
                updS.Inbound_QTY__c = 0;
                updS.Inbound_Amount__c = 0;
                updSummaries.put(order.Return_Summary__c, updS);
            }
        }
    }
    // order删除时
    if(Trigger.isDelete) {
        for (RTV_Order__c order: Trigger.old) {
            if (order.Return_Summary__c != null) {
                
                RTV_Summary__c updS = new RTV_Summary__c();
                updS.Id = order.Return_Summary__c;
                updS.Application_QTY__c = 0;
                updS.Application_Amount__c = 0;
                updS.Delivery_QTY__c = 0;
                updS.Inspect_QTY_A__c = 0;
                updS.Inspect_QTY_B__c = 0;
                updS.Inspect_QTY_C__c = 0;
                updS.Inspect_QTY_D__c = 0;
                updS.Inspect_Amount_A__c = 0;
                updS.Inspect_Amount_B__c = 0;
                updS.Inspect_Amount_D__c = 0;
                updS.Inbound_QTY__c = 0;
                updS.Inbound_Amount__c = 0;
                updSummaries.put(order.Return_Summary__c, updS);
            }
        }
    }
    // order的qty和amount更新时
    if(Trigger.isUpdate) {
        for (RTV_Order__c order: Trigger.new) {
            if (order.Return_Summary__c != null) {
                
                RTV_Order__c orderOld = Trigger.oldMap.get(order.Id);
                if (order.Application_QTY__c != orderOld.Application_QTY__c
                    || order.Application_Amount__c != orderOld.Application_Amount__c
                    || order.Delivery_QTY__c != orderOld.Delivery_QTY__c
                    || order.Inspect_QTY_A__c != orderOld.Inspect_QTY_A__c
                    || order.Inspect_QTY_B__c != orderOld.Inspect_QTY_B__c
                    || order.Inspect_QTY_C__c != orderOld.Inspect_QTY_C__c
                    || order.Inspect_QTY_D__c != orderOld.Inspect_QTY_D__c
                    || order.Inbound_QTY__c != orderOld.Inbound_QTY__c
                    || order.Inspect_Amount_A__c != orderOld.Inspect_Amount_A__c
                    || order.Inspect_Amount_B__c != orderOld.Inspect_Amount_B__c
                    || order.Inspect_Amount_D__c != orderOld.Inspect_Amount_D__c
                    || order.Inbound_Amount__c != orderOld.Inbound_Amount__c
                ) {
                    RTV_Summary__c updS = new RTV_Summary__c();
                    updS.Id = order.Return_Summary__c;
                    updS.Application_QTY__c = 0;
                    updS.Application_Amount__c = 0;
                    updS.Delivery_QTY__c = 0;
                    updS.Inspect_QTY_A__c = 0;
                    updS.Inspect_QTY_B__c = 0;
                    updS.Inspect_QTY_C__c = 0;
                    updS.Inspect_QTY_D__c = 0;
                    updS.Inspect_Amount_A__c = 0;
                    updS.Inspect_Amount_B__c = 0;
                    updS.Inspect_Amount_D__c = 0;
                    updS.Inbound_QTY__c = 0;
                    updS.Inbound_Amount__c = 0;
                    updSummaries.put(order.Return_Summary__c, updS);
                }
                
            }
        }
    }
    
    // -------------------------------
    // 重新统计目标summary的qty和amount
    // -------------------------------
    if(updSummaries.size() > 0){
        Boolean hasError = false;
        
        for(AggregateResult orderGroup: [
            SELECT Return_Summary__c, 
                Return_Summary__r.Status__c summaryStatus, 
                Return_Summary__r.Summary_Type__c sumType,
                MIN(Return_Summary__r.Summary_Budget__r.QTY__c) budgetQty,
                MIN(Return_Summary__r.Summary_Budget__r.Tack_Back_Net__c) budgetNet,
                SUM(Application_QTY__c) Application_QTY__c,
                SUM(Application_Amount__c) Application_Amount__c,
                SUM(Delivery_QTY__c) Delivery_QTY__c,
                SUM(Inspect_QTY_A__c) Inspect_QTY_A__c,
                SUM(Inspect_QTY_B__c) Inspect_QTY_B__c,
                SUM(Inspect_QTY_C__c) Inspect_QTY_C__c,
                SUM(Inspect_QTY_D__c) Inspect_QTY_D__c,
                SUM(Inbound_Amount__c) Inbound_Amount__c,
                SUM(Inbound_QTY__c) Inbound_QTY__c,
                SUM(Inspect_Amount_A__c) Inspect_Amount_A__c,
                SUM(Inspect_Amount_B__c) Inspect_Amount_B__c,
                SUM(Inspect_Amount_D__c) Inspect_Amount_D__c,
                SUM(Takeback_NET__c) actualNet
            FROM RTV_Order__c
            WHERE Return_Summary__c IN :updSummaries.KeySet()
            AND Return_Summary__r.Summary_Budget__c != null
            GROUP BY Return_Summary__c, Return_Summary__r.Status__c, Return_Summary__r.Summary_Type__c
        ]) {
            RTV_Summary__c updS = updSummaries.get((Id)orderGroup.get('Return_Summary__c'));
            updS.Application_QTY__c = (Decimal)orderGroup.get('Application_QTY__c');
            updS.Application_Amount__c = (Decimal)orderGroup.get('Application_Amount__c');
            updS.Delivery_QTY__c = (Decimal)orderGroup.get('Delivery_QTY__c');
            updS.Inspect_QTY_A__c = (Decimal)orderGroup.get('Inspect_QTY_A__c');
            updS.Inspect_QTY_B__c = (Decimal)orderGroup.get('Inspect_QTY_B__c');
            updS.Inspect_QTY_C__c = (Decimal)orderGroup.get('Inspect_QTY_C__c');
            updS.Inspect_QTY_D__c = (Decimal)orderGroup.get('Inspect_QTY_D__c');
            updS.Inbound_Amount__c = (Decimal)orderGroup.get('Inbound_Amount__c');
            updS.Inbound_QTY__c = (Decimal)orderGroup.get('Inbound_QTY__c');
            updS.Inspect_Amount_A__c = (Decimal)orderGroup.get('Inspect_Amount_A__c');
            updS.Inspect_Amount_B__c = (Decimal)orderGroup.get('Inspect_Amount_B__c');
            updS.Inspect_Amount_D__c = (Decimal)orderGroup.get('Inspect_Amount_D__c');
            
            Boolean isWSL = (String)orderGroup.get('sumType') == 'WSL Takeback';
            
            // WSL的summary，在Ready状态时，检查application的预算
            if (isWSL && orderGroup.get('summaryStatus') == 'Ready') {
                Long budgetQty = ((Decimal)orderGroup.get('budgetQty')).round();
                Decimal budgetNet = ((Decimal)orderGroup.get('budgetNet')).setScale(2, System.RoundingMode.HALF_UP);
                Long applyQty = updS.Application_QTY__c.round();
                Decimal applyNet = updS.Application_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
                
                // QTY预算
                if (budgetQty > 0 && applyQty > budgetQty) {
                    hasError = true;
                    
                    String errmsg = '已超出预算' + '(预算QTY=' + budgetQty + ')(实际QTY=' + applyQty + ')';
                    Trigger.new[0].addError(errmsg);
                } 
                // 金额(NET)预算
                if (budgetNet > 0 && applyNet > budgetNet) {
                    hasError = true;
                    
                    String errmsg = '已超出预算' + '(预算总金额=' + budgetNet + ')(实际总金额=' + applyNet + ')';
                    Trigger.new[0].addError(errmsg);
                }
            }else if(isWSL && orderGroup.get('summaryStatus') == 'POST to LF'){
                //在调整完sellingprice后实际退货金额可能会超出BP指定的Account预算金额，这里做控制。
                Decimal budgetNet = ((Decimal)orderGroup.get('budgetNet')).setScale(2, System.RoundingMode.HALF_UP);
                Decimal actualNet = ((Decimal)orderGroup.get('actualNet')).setScale(2, System.RoundingMode.HALF_UP);
                if (budgetNet > 0 && actualNet > budgetNet) {
                    hasError = true;
                    
                    String errmsg = '已超出预算' + '(预算总金额=' + budgetNet + '(美元除税))(实际退货总金额=' + actualNet + '(美元除税))';
                    Trigger.new[0].addError(errmsg);
                }
            }
            updSummaries.put(updS.Id, updS);
        }
        if (hasError == false) {
            update updSummaries.values();
        }
    }
}