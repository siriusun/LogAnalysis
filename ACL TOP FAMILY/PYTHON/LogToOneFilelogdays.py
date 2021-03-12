import pandas as pd
import os

logpath = r"D:\Sync_ColorCloud\LogAnalysis\AllWerfenChinaTop\IndirectService202103\Data\TT"
colfilter = ["sCode", "eType", "dateTime", "funcArea", "sDescription"]
replace_dic = {
    "开机": "Power up",
    "初始化": "Initializing",
    "维护": "Maintenance",
    "错误": "Error",
    "紧急停止": "Emergency stop",
    "忙": "Busy",
    "诊断": "Diagnostics",
    "准备": "Ready",
    "受控停机": "Controlled stop",
    "未连接": "Not connected",
    "温度调整": "Adjusting thermal",
    "分析仪状态从": "Analyzer Status changed from",
    "变为": "to",
    "样品": "SAMPLE",
    "试剂1": "REAGENT 1",
    "试剂2": "REAGENT 2"
}


def file_filter(filedir, keyword):
    allfilelist = os.listdir(filedir)
    targetfiles = []
    for f in allfilelist:
        if keyword in f:
            targetfiles.append(f)
    return targetfiles


def replace_desp(desp):
    for (cn, en) in replace_dic.items():
        desp = desp.replace(cn, en)
    return desp


def logaddsq(logfullpath, filter_col,
             log_days):  #log_days为0，则保留全部日志，传入数字，保留固定天数日志。
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog0 = tlog0.dropna(axis=0, how="any")
    tlog0["sDescription"] = tlog0["sDescription"].apply(replace_desp)
    tlog1 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog1 = tlog1.dropna(axis=0, how="any")
    tlog1["sDescription"] = tlog1["sDescription"].apply(replace_desp)
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    log_gen_time = pd.to_datetime(logwithsq.iloc[-1, 2])
    if log_days != 0:
        logwithsq["log_days"] = (log_gen_time - pd.to_datetime(logwithsq["dateTime_x"])
                ) / pd.Timedelta(1, "d") - log_days < 0
        logwithsq = logwithsq[logwithsq.log_days == True]
    return logwithsq


loglist = file_filter(logpath, ".txt")
for i in range(len(loglist)):
    print("Starting load file :{}".format(i))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter,90) #最后参数为0，则保留全部日志，填写数字，保留固定天数日志。
    logtemp = logtemp[(
        (logtemp.eType_x == "ERROR") | (logtemp.eType_x == "INFORMATION"))
                      & ((logtemp.funcArea_x == "Analyzer")
                         | (logtemp.funcArea_x == "Materials"))]
    logtemp = logtemp[
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Ready to Maintenance.")
        & (logtemp.sDescription_x !=
           "Analyzer Status changed from Maintenance to Ready.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Busy to Ready.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Not connected to Power up.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Power up to Initializing.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Initializing to Adjusting thermal.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Adjusting thermal to Ready.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Ready to Initializing.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Busy to Controlled stop.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Controlled stop to Busy.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Emergency stop to Not connected.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Error to Ready.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Ready to Error.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Diagnostics to Emergency stop.") &
        (logtemp.sDescription_x !=
         "Analyzer Status changed from Power up to Diagnostics.")]
    logtemp = logtemp[(logtemp.sCode_x != "'03218")
                      & (logtemp.sCode_x != "'03004") &
                      (logtemp.sCode_x != "'02083") &
                      (logtemp.sCode_x != "'02025") &
                      (logtemp.sCode_x != "'03215") &
                      (logtemp.sCode_x != "'03188") &
                      (logtemp.sCode_x != "'02055")]
    logtemp["TopSn"] = loglist[i][:-4]
    if i == 0:
        logonefile = logtemp
        continue
    logonefile = logonefile.append(logtemp, colfilter)

logonefile = logonefile.rename(
    columns={
        "sCode_x": "sCode",
        "eType_x": "eType",
        "dateTime_x": "dateTime",
        "funcArea_x": "funcArea",
        "sDescription_x": "sDescription",
        "sCode_y": "sCodeSQ",
        "eType_y": "eTypeSQ",
        "dateTime_y": "dateTimeSQ",
        "funcArea_y": "funcAreaSQ",
        "sDescription_y": "sDescriptionSQ"
    })
logonefile["Timediff"] = (
    pd.to_datetime(logonefile["dateTimeSQ"]) -
    pd.to_datetime(logonefile["dateTime"])) / pd.Timedelta(1, "S")
logonefile["Timediff<10s"] = logonefile["Timediff"].apply(lambda x: "Y"
                                                          if x < 10 else "N")
logonefile.drop(["eTypeSQ", "funcAreaSQ"], axis=1, inplace=True)
logonefile.insert(0, "TopSn", logonefile.pop("TopSn"))
logonefile.to_csv((logpath + "\\one.csv"))
print("Done")
