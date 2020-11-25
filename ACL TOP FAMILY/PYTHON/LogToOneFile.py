import pandas as pd
import numpy as np
import os
import re


def file_filter(filedir, keyword):
    allfilelist = os.listdir(filedir)
    targetfiles = []
    for f in allfilelist:
        if keyword in f:
            targetfiles.append(f)
    return targetfiles


def logaddsq(logfullpath, filter_col):
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog1 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf-16",
                        usecols=filter_col)
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    return logwithsq


#def replace_desp(desp):
#desp = re.sub(" [RD][A-F][^A-Z]"," <Rack>",desp,count=0,flags=0)
#desp = re.sub(" [DRS]\d{1,}"," <RackXX>",desp,count=0,flags=0)
#desp = re.sub("\d{1,}","<XX>",desp,count=0,flags=0)

logpath = r"D:\LogAnalysis\AllWerfenChinaTop\202010\GeneralLogs"
colfilter = ["sCode", "eType", "dateTime", "funcArea", "sDescription"]
loglist = file_filter(logpath, ".txt")

logtemp = logaddsq((logpath + "\\" + loglist[0]), colfilter)
logtemp = logtemp.dropna(axis=0, how="any")
logtemp = logtemp[(
    (logtemp.eType_x == "ERROR") | (logtemp.eType_x == "INFORMATION"))
                  & ((logtemp.funcArea_x == "Analyzer")
                     | (logtemp.funcArea_x == "Materials"))]
logtemp["TopSn"] = loglist[0][:-4]
logonefile=logtemp

for i in range(1, len(loglist)):
    print("Starting load file :{}".format(i))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter)
    logtemp = logtemp.dropna(axis=0, how="any")
    logtemp = logtemp[(
        (logtemp.eType_x == "ERROR") | (logtemp.eType_x == "INFORMATION"))
                      & ((logtemp.funcArea_x == "Analyzer")
                         | (logtemp.funcArea_x == "Materials"))]
    logtemp["TopSn"] = loglist[i][:-4]
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
logonefile["sDescriptionSQ"] = logonefile["sDescriptionSQ"].replace(
    ".*(忙|Busy).*(Emer|紧急).*",
    "Analyzer Status changed from Busy to Emergency stop.",
    regex=True)
#logonefile["sDescription"] = logonefile["sDescription"].apply(replace_desp)

logonefile.drop(["eTypeSQ", "funcAreaSQ"], axis=1, inplace=True)
logonefile.insert(0, "TopSn", logonefile.pop("TopSn"))
logonefile.to_csv((logpath + "\\one.csv"))
print("Done")