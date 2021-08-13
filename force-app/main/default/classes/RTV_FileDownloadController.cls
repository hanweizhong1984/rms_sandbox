public with sharing class RTV_FileDownloadController {
    //附件
    public transient Attachment attach{get;set;}
    //附件列表
    public List<Attachment> attList{get;set;}
    //help对象
    private RMS_Help__c help;
    //help列表
    private List<RMS_Help__c> helpList;
    //权限
    public String profile{get;set;}
    //权限列表
    public List<SelectOption> profileList{
        get{
            List<SelectOption> selList = new List<SelectOption>();
            selList.add(new SelectOption('ALL','ALL'));
            selList.add(new SelectOption('LF','LF'));
            selList.add(new SelectOption('WSL','WSL'));
            selList.add(new SelectOption('BP','BP'));
            selList.add(new SelectOption('BP(CFS)','BP(CFS)'));
            selList.add(new SelectOption('BP(DIG)','BP(DIG)'));
            selList.add(new SelectOption('CS','CS'));
            return selList;
        }
    }
    //文件内容
    public transient Blob fileBody{get;set;}
    //文件名
    public String fileName{get;set;}
    //是否为管理员
    public Boolean isAdmin{get;set;}
    //文件描述
    public String fileDescription{get;set;}
    //是否为编辑状态
    public Boolean isUpdate{get;set;}
    //当前用户信息
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();

    /**
     * 构造方法
     * 根据不同用户显示不同附件列表
     */
    public RTV_FileDownloadController(){
 
       this.helpList = new List<RMS_Help__c>();

       this.isAdmin = false;
       //获得当前用户简档
       Profile userProfile = [SELECT Name FROM Profile Where Id = :UserInfo.getProfileId() LIMIT 1];
       //LF用户
       if(loginUser.isLF)
       {
           this.helpList = [SELECT ID FROM RMS_Help__c WHERE name = 'LF' OR name = 'ALL']; 
       }
       //WSL用户
       if(loginUser.isWSL)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c WHERE name = 'WSL' OR name = 'ALL']; 
       }
       //CS用户
       if(loginUser.isCS)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c]; 
       }
       //WSL_BP用户
       if(loginUser.isWslBP)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c WHERE name = 'BP' OR name = 'ALL']; 
       }
       //Admin用户
       if(loginUser.isAdmin)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c]; 
            isAdmin = true;
       }
       //CFS_BP用户
       if(loginUser.isDtcCfsBP)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c WHERE name = 'BP(CFS)' OR name = 'ALL']; 
       }
       //DIG_BP用户
       if(loginUser.isDtcDigBP)
       {
            this.helpList = [SELECT ID FROM RMS_Help__c WHERE name = 'BP(DIG)' OR name = 'ALL']; 
       }
       this.attList = [SELECT ID,NAME,BODY,Description,Contenttype FROM Attachment WHERE parentid IN:this.helpList Order By NAME];
    }

    /**上传附件 */
    public void attach(){
        //初始化
        this.attach =  new Attachment();
        //判断文件内容是否为空
        if(fileBody == null)
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.WARNING, 'Empty File!'));
            return;
        }
        try{
            this.help = [SELECT ID FROM RMS_Help__c WHERE name = :this.profile];

            //附件信息
            attach.parentid = this.help.id ;
            attach.body = this.fileBody;
            attach.name = this.fileName;
            attach.description = this.fileDescription;
            insert attach;

            //刷新附件列表
            this.attList = [SELECT ID,NAME,BODY,Description,Contenttype FROM Attachment WHERE parentid IN:this.helpList  Order By NAME];
    
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'Upload Success!'));
        
            }
        catch(Exception e){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, 'Upload Fail!'+e));
            }

    }
    /**下载附件 */
    public ApexPages.Pagereference downloadURL(){
        //获取附件ID
        String fileId= Apexpages.currentPage().getParameters().get('fileId');

        return new Pagereference ('/servlet/servlet.FileDownload?file='+fileId);
    }
    /**删除附件 */
    public void deleteFile(){
        //获取附件ID
        String delfileId= Apexpages.currentPage().getParameters().get('delfileId');
        Attachment attach = [SELECT ID FROM Attachment WHERE ID=:delfileId];
        delete attach;
        //更新附件列表
        this.attList = [SELECT ID,NAME,BODY,Description,Contenttype FROM Attachment WHERE parentid IN:this.helpList Order By NAME];

        ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'Delete Success!'));
    }
    /**编辑文件描述*/
    public void updateFile(){
        this.isUpdate = true;
    }
    /**保存文件描述 */
    public void saveFile(){
        this.isUpdate = false;
        update attList;
        this.attList = [SELECT ID,NAME,BODY,Description,Contenttype FROM Attachment WHERE parentid IN:this.helpList  Order By NAME];
    }
}