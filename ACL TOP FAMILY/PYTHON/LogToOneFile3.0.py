import pandas as pd
import copy as cp
import os
import datetime as dt

logpath = os.path.split(os.path.abspath(__file__))[0] + "\\GeneralLogs"
print("\n")
print("*" * 150)
print("Log working folder>>:")
print(logpath)
print("*" * 150)
os.system("pause")
start = dt.datetime.now()
peroid = 0 #日志保留天数,0则全部保留
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

Filter_List_sDescription = [
    "INFORMATION:Analyzer Status changed from Busy to Controlled stop.",
    "INFORMATION:Analyzer Status changed from Busy to Emergency stop.",
    "INFORMATION:Analyzer Status changed from Controlled stop to Emergency stop.",
    "INFORMATION:Analyzer Status changed from Initializing to Emergency stop.",
    "INFORMATION:Analyzer Status changed from Initializing to Error.",
    "INFORMATION:Analyzer Status changed from Maintenance to Emergency stop.",
    "INFORMATION:Analyzer Status changed from Maintenance to Error.",
]

Filter_List_sCode = [
    "'03218", "'03004", "'02083", "'02025", "'03215", "'03188", "'02055"
]

Filter_List_funcArea = ["Analyzer", "Materials"]
Filter_List_eType = ["ERROR", "INFORMATION"]


def file_filter(filedir, keyword):
    allfilelist = os.listdir(filedir)
    targetfiles = []
    for f in allfilelist:
        if keyword in f:
            targetfiles.append(f)
    return targetfiles

def info_filter(infostr):
    if ("ERROR:" in infostr) or (infostr in Filter_List_sDescription):
        return "Y"
    else:
        return "N"

def replace_desp(desp):
    if "分析仪状态从" != desp[0:6]:
        return desp
    for (cn, en) in replace_dic.items():
        desp = desp.replace(cn, en)
    return desp

def logaddsq(logfullpath, filter_col,
             log_days):  #log_days为0，则保留全部日志，传入数字，保留固定天数日志。
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf_16_le",
                        usecols=filter_col)
    tlog0 = tlog0.dropna(axis=0, how="any")
    log_gen_time = pd.to_datetime(tlog0.iloc[-1, 2])
    #筛选掉无用数据
    tlog0 = tlog0[(tlog0.funcArea.isin(Filter_List_funcArea))
                  & (tlog0.eType.isin(Filter_List_eType))]
    tlog0["sDescription"] = tlog0["sDescription"].apply(replace_desp)
    tlog0 = tlog0[(tlog0.eType == "ERROR")
                  | ((tlog0.eType == "INFORMATION")
                     & (tlog0.sDescription.isin(Filter_List_sDescription)))]
    tlog0 = tlog0[~tlog0.sCode.isin(Filter_List_sCode)]
    tlog0.reset_index(drop=True,inplace=True)
    tlog1 = cp.copy(tlog0)
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    if log_days != 0:
        logwithsq["log_days"] = (log_gen_time - pd.to_datetime(logwithsq["dateTime_x"])
                ) / pd.Timedelta(1, "d") - log_days < 0
        logwithsq = logwithsq[logwithsq.log_days == True]
    return logwithsq

loglist = file_filter(logpath, ".txt")
for i in range(len(loglist)):
    print("Starting load file :{}".format(i+1))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter,peroid) #最后参数为0，则保留全部日志，填写数字，保留固定天数日志。
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
logonefile.drop(["eTypeSQ", "funcAreaSQ", "dateTimeSQ"], axis=1, inplace=True)
logonefile.insert(0, "TopSn", logonefile.pop("TopSn"))
logonefile["log_days"] = peroid
logonefile.to_csv((logpath + "\\one.csv"))
print("Done")

print(dt.datetime.now() - start)
