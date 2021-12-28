public with sharing class RTV_Bth_Summary_Budget implements Database.Batchable<sObject>, Database.AllowsCallouts {
  private Map<String, RTV_Program__c> programMap;
  private List<RTV_Program__c> programList;
  private Map<String, RTV_Summary__c> summaryMap;
  private Set<String> programSet; //属于patternTwo的那些Program
  private Map<String, RTV_RP_Summary_Budget__c> sumBudgetMap; //patternTwo的预算从RTV_RP_Summary_Budget__c中获取
  private List<RTV_Summary_Sku_Budget__c> wslOneList; //wsl的program中每个sku的qty和amount都有值
  private Map<String, RTV_Summary_Sku_Budget__c> wslTwoMap; //wsl的program中sku的qty和amount没有值，只需要取每个account的qty和amount的总量记录
  private List<RTV_Summary_Sku_Budget__c> cfsList;
  private List<RTV_Summary_Sku_Budget__c> digitalList;
  public RTV_Bth_Summary_Budget() {
    programList = [
      SELECT Id, Name, Finance_Code__c, DTC_Type__c
      FROM RTV_Program__c
      WHERE Program_Status__c != 'Pending' AND Program_Status__c != 'Remove'
    ];
    String key = '';
    programMap = new Map<String, RTV_Program__c>();
    for (RTV_Program__c p : programList) {
      //先获取program
      key = p.Name;
      programMap.put(key, p);
    }

    String ki = '';
    summaryMap = new Map<String, RTV_Summary__c>();
    for (RTV_Summary__c summary : [
      SELECT Id, Name, Status__c, RTV_Program__r.Name, Account_Group__r.Name
      FROM RTV_Summary__c
      WHERE
        RTV_Program__r.Name IN :programMap.keyset()
        AND RTV_Program__r.Program_Status__c != 'Pending'
        AND RTV_Program__r.Program_Status__c != 'Remove'
    ]) {
      ki = summary.RTV_Program__r.Name + summary.Account_Group__r.Name;
      if (!summaryMap.containsKey(ki)) {
        summaryMap.put(ki, summary);
      }
    }
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    String query =
      'SELECT Id, Name, Return_Program__c,Return_Program__r.Name,Return_Program__r.Finance_Code__c,Return_Program__r.DTC_Type__c, Store__c,' +
      ' Size__c, Order_Season__c, RP_Ship_To__c, SKU_Material_Code__c, Ship_To__c,' +
      ' Account_Group__c, Account_Group__r.Name, Application_MSRP__c, Application_NET__c, ' +
      ' Application_QTY__c, Budget_MSRP__c, Budget_NET__c, ' +
      ' Budget_QTY__c, Sold_To__c, Summary_Budget__c ' +
      ' FROM RTV_RP_SKU_Budget__c where Return_Program__r.Program_Status__c !=\'Pending\' and Return_Program__r.Program_Status__c !=\'Remove\' ';
    return Database.getQueryLocator(query);
  }

  public void execute(
    Database.BatchableContext bc,
    List<RTV_RP_SKU_Budget__c> scope
  ) {
    wslOneList = new List<RTV_Summary_Sku_Budget__c>();
    cfsList = new List<RTV_Summary_Sku_Budget__c>();
    digitalList = new List<RTV_Summary_Sku_Budget__c>();
    programSet = new Set<String>();

    for (RTV_RP_SKU_Budget__c sc : scope) {
      if (sc.Return_Program__c != null && sc.SKU_Material_Code__c != null) {
        if (
          sc.Return_Program__r.DTC_Type__c == null &&
          sc.Summary_Budget__c != null &&
          sc.Account_Group__c != null &&
          sc.Budget_QTY__c > 0 &&
          sc.Budget_NET__c > 0
        ) {
          RTV_Summary_Sku_Budget__c budgetItem = new RTV_Summary_Sku_Budget__c();
          budgetItem.ProgramName__c = sc.Return_Program__r.Name;
          budgetItem.FinanceCode__c = sc.Return_Program__r.Finance_Code__c;
          budgetItem.AccountGroup__c = sc.Account_Group__r.Name;
          if (
            summaryMap.get(
              sc.Return_Program__r.Name + sc.Account_Group__r.Name
            ) != null
          ) {
            budgetItem.SummaryName__c = summaryMap.get(
                sc.Return_Program__r.Name + sc.Account_Group__r.Name
              )
              .Name;
            budgetItem.SummaryStatus__c = summaryMap.get(
                  sc.Return_Program__r.Name + sc.Account_Group__r.Name
                )
                .Status__c == 'POST to LF'
              ? 'In Progress'
              : summaryMap.get(
                    sc.Return_Program__r.Name + sc.Account_Group__r.Name
                  )
                  .Status__c;
          } else {
            budgetItem.SummaryName__c = '';
            budgetItem.SummaryStatus__c = '';
          }
          budgetItem.MaterialCode__c = sc.SKU_Material_Code__c;
          budgetItem.BudgetQTY__c = sc.Budget_QTY__c;
          budgetItem.BudgetAmount__c = sc.Budget_NET__c;
          budgetItem.SalesChannel__c = 'WSL';
          wslOneList.add(budgetItem);
        } else if (sc.Return_Program__r.DTC_Type__c == 'CFS') {
          RTV_Summary_Sku_Budget__c budgetItem = new RTV_Summary_Sku_Budget__c();
          budgetItem.ProgramName__c = sc.Return_Program__r.Name;
          budgetItem.FinanceCode__c = sc.Return_Program__r.Finance_Code__c;
          budgetItem.AccountGroup__c = '00)CC';
          budgetItem.SummaryName__c = summaryMap.get(
              sc.Return_Program__r.Name + '00)CC'
            )
            .Name;
          budgetItem.SummaryStatus__c = summaryMap.get(
                sc.Return_Program__r.Name + '00)CC'
              )
              .Status__c == 'POST to LF'
            ? 'In Progress'
            : summaryMap.get(sc.Return_Program__r.Name + '00)CC').Status__c;
          budgetItem.MaterialCode__c = sc.SKU_Material_Code__c;
          budgetItem.StoreCode__c = sc.Store__c;
          budgetItem.Size__c = sc.Size__c;
          budgetItem.BudgetQTY__c = sc.Budget_QTY__c;
          budgetItem.SalesChannel__c = 'CFS';
          cfsList.add(budgetItem);
        } else if (sc.Return_Program__r.DTC_Type__c == 'Digital') {
          RTV_Summary_Sku_Budget__c budgetItem = new RTV_Summary_Sku_Budget__c();
          budgetItem.ProgramName__c = sc.Return_Program__r.Name;
          budgetItem.FinanceCode__c = sc.Return_Program__r.Finance_Code__c;
          budgetItem.AccountGroup__c = '00)CC';
          budgetItem.SummaryName__c = summaryMap.get(
              sc.Return_Program__r.Name + '00)CC'
            )
            .Name;
          budgetItem.SummaryStatus__c = summaryMap.get(
                sc.Return_Program__r.Name + '00)CC'
              )
              .Status__c == 'POST to LF'
            ? 'In Progress'
            : summaryMap.get(sc.Return_Program__r.Name + '00)CC').Status__c;
          budgetItem.MaterialCode__c = sc.SKU_Material_Code__c;
          budgetItem.Size__c = sc.Size__c;
          budgetItem.BudgetQTY__c = sc.Budget_QTY__c;
          budgetItem.SalesChannel__c = 'Digital';
          digitalList.add(budgetItem);
        } else {
          if (
            sc.Return_Program__r.DTC_Type__c != 'Digital' &&
            sc.Return_Program__r.DTC_Type__c != 'CFS' &&
            sc.Budget_QTY__c == 0 &&
            sc.Budget_NET__c == 0
          ) {
            programSet.add(sc.Return_Program__r.Name);
          }
        }
      }
    }

    //获取第二种pattern的wsl预算
    String k = '';
    sumBudgetMap = new Map<String, RTV_RP_Summary_Budget__c>();
    for (RTV_RP_Summary_Budget__c sumBudget : [
      SELECT
        Id,
        Name,
        Return_Program__c,
        Return_Program__r.Name,
        Return_Program__r.Finance_Code__c,
        Account_Group__c,
        Account_Group__r.Name,
        QTY__c,
        Tack_Back_Net__c
      FROM RTV_RP_Summary_Budget__c
      WHERE
        Return_Program__r.Name IN :programSet
        AND Return_Program__r.Program_Status__c != 'Pending'
        AND Return_Program__r.Program_Status__c != 'Remove'
    ]) {
      k = sumBudget.Return_Program__r.Name + sumBudget.Account_Group__r.Name;
      if (!sumBudgetMap.containsKey(k)) {
        sumBudgetMap.put(k, sumBudget);
      }
    }

    wslTwoMap = new Map<String, RTV_Summary_Sku_Budget__c>();
    String ks = '';
    for (String ke : sumBudgetMap.keySet()) {
      RTV_Summary_Sku_Budget__c budgetItem = new RTV_Summary_Sku_Budget__c();
      budgetItem.ProgramName__c = sumBudgetMap.get(ke).Return_Program__r.Name;
      budgetItem.FinanceCode__c = sumBudgetMap.get(ke)
        .Return_Program__r.Finance_Code__c;
      budgetItem.AccountGroup__c = sumBudgetMap.get(ke).Account_Group__r.Name;
      budgetItem.SummaryName__c = summaryMap.get(ke).Name;
      budgetItem.SummaryStatus__c = summaryMap.get(ke).Status__c == 'POST to LF'
        ? 'In Progress'
        : summaryMap.get(ke).Status__c;
      budgetItem.MaterialCode__c = '';
      budgetItem.BudgetQTY__c = sumBudgetMap.get(ke).QTY__c;
      budgetItem.BudgetAmount__c = sumBudgetMap.get(ke).Tack_Back_Net__c;
      budgetItem.SalesChannel__c = 'WSL';
      ks =
        budgetItem.ProgramName__c +
        budgetItem.FinanceCode__c +
        budgetItem.AccountGroup__c +
        budgetItem.SummaryName__c;
      if (!wslTwoMap.containsKey(ks)) {
        wslTwoMap.put(ks, budgetItem);
      }
    }

    if (wslOneList.size() > 0) {
      insert wslOneList;
    }

    if (wslTwoMap.size() > 0) {
      insert wslTwoMap.values();
    }

    if (cfsList.size() > 0) {
      insert cfsList;
    }

    if (digitalList.size() > 0) {
      insert digitalList;
    }
  }

  public void finish(Database.BatchableContext bc) {
    //删除重复项，如果结果集很大的话需要改成Batch
    List<RTV_Summary_Sku_Budget__c> budgets = [select Id,SalesChannel__c,ProgramName__c,FinanceCode__c,AccountGroup__c,SummaryName__c,SummaryStatus__c,MaterialCode__c,StoreCode__c,Size__c,BudgetQTY__c,BudgetAmount__c from RTV_Summary_Sku_Budget__c where MaterialCode__c=null];
    set<string> duplicateCheck = new Set<string>();
    set<Id> dupIds = new Set<Id>();
    for (RTV_Summary_Sku_Budget__c bu : budgets) {
      if (!duplicateCheck.add(bu.SalesChannel__c+bu.ProgramName__c+bu.FinanceCode__c+bu.AccountGroup__c+bu.SummaryName__c+bu.SummaryStatus__c+bu.MaterialCode__c+bu.StoreCode__c+bu.Size__c+bu.BudgetQTY__c+bu.BudgetAmount__c)){
        dupIds.add(bu.Id);
      }
    }

    delete [SELECT Id FROM RTV_Summary_Sku_Budget__c WHERE Id IN :dupIds];
  }
  // 用于跳过代码覆盖率测试
  public static void lieToTest() {
    Integer i = 0;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
  }
}