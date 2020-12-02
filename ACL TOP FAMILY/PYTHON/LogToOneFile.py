import pandas as pd
import os


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


def logaddsq(logfullpath, filter_col):
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog0["sDescription"] = tlog0["sDescription"].apply(replace_desp)
    tlog1 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog1["sDescription"] = tlog1["sDescription"].apply(replace_desp)
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    return logwithsq


logpath = r"D:\LogAnalysis\AllWerfenChinaTop\202010\GeneralLogs"
colfilter = ["sCode", "eType", "dateTime", "funcArea", "sDescription"]
loglist = file_filter(logpath, ".txt")
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
    "变为": "to"
}

for i in range(len(loglist)):
    print("Starting load file :{}".format(i))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter)
    logtemp = logtemp.dropna(axis=0, how="any")
    logtemp = logtemp[(
        (logtemp.eType_x == "ERROR") | (logtemp.eType_x == "INFORMATION"))
                      & ((logtemp.funcArea_x == "Analyzer")
                         | (logtemp.funcArea_x == "Materials"))]
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
