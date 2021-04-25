#Modify 2021/04/15 09:16

import pandas as pd
import copy as cp
import os
import datetime as dt
import tkinter.filedialog as tk
import tkinter

#logpath = os.path.split(os.path.abspath(__file__))[0] + "\\GeneralLogs"
root = tkinter.Tk()
root.withdraw()
logpath = tk.askdirectory()

print("\n")
print("*" * 150)
print("Log working folder>>:")
print(logpath)
print("*" * 150)
os.system("pause")
start = dt.datetime.now()
peroid = 0  #log reserve days; 0 means all.
colfilter = [
    "sCode", "eType", "dateTime", "funcArea", "sDescription", "sFilename",
    "nSubCode", "eCPU"
]
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

#"Analyzer Status changed from Busy to Controlled stop.",
#Selected sDescription list
Filter_List_sDescription = [
    "Analyzer Status changed from Busy to Emergency stop.",
    "Analyzer Status changed from Controlled stop to Emergency stop.",
    "Analyzer Status changed from Initializing to Emergency stop.",
    "Analyzer Status changed from Initializing to Error.",
    "Analyzer Status changed from Maintenance to Emergency stop.",
    "Analyzer Status changed from Maintenance to Error."
]

#Unselected sCode list
Filter_List_sCode = [
    "'03218", "'03004", "'02083", "'02025", "'03215", "'03188", "'02055",
    "'03184", "'01285", "'01336", "'02077", "'03007", "'03014", "'00056",
    "'03013", "'03084", "'03016", "'03085", "'03211", "'03020", "'03019",
    "'03005", "'03011", "'03018", "'03015", "'03017", "'03009", "'03010",
    "'03021"
]
'''
03218: Non-identified Sample in rack <rack> position <position>, track <track>.
03004: Non-identified Material in rack <rack> position <position>, track <track>.
02083: <Material> insufficient material to run additional calibration / test.
02025: Cuvettes waste drawer missing.
03215: LAS sample expiration time exceeded for <sample>.
03188: Volume check not performed (Factor Diluent in rack <rack>, position <position>, <track>).
02055: Insufficient volume in position <position>, track <track>.
03184: <test> Patient job not feasible. Sample <sample> has expired.
01285: Probe <ARM> Liquid Level Detection error in rack position <position>, track <track>.
01336: Probe LAS Liquid Level Detection error in LAS Arm cover aspiration point.
02077: Insufficient volume in LAS Arm cover aspiration point.
03007: Unknown lot (<Material> in rack <rack> position <position>, track <track>).
03014: Placement error (<Material> in rack <rack>, position <position>, track <track>).
00056: Interrupted communication between the Analyzer and the Control Module.
03013: Placement error (<Material> in rack <rack>, position <position>, track <track>).
03084: <Material> on-board stability expired for last available vial.
03016: Placement error (<Material> in rack <rack>, position <position>, track <track>).
03085: Anti Chromogenic Sub expired.
03211: Auto Run failed.
03020: Placement error (<Material> in rack <rack>, position <position>, track <track>).
03019: Placement error (<Material> in rack <rack>, position <position>, track <track>).
03005: Unknown material in rack <rack> position <position>, track <track>.
03011: Placement error
03018: Placement error
03015: Placement error
03017: Placement error
03009: Placement error
03021: Placement error
03010: Placement error
'''

#Selected funcArea/eType list
Filter_List_funcArea = ["Analyzer", "Materials"]
Filter_List_eType = ["ERROR", "INFORMATION"]


def file_filter(filedir, keyword):
    allfilelist = os.listdir(filedir)
    targetfiles = [file for file in allfilelist if keyword in file]
    return targetfiles

'''
def info_filter(infostr):
    if ("ERROR:" in infostr) or (infostr in Filter_List_sDescription):
        return "Y"
    else:
        return "N"
'''


def replace_desp(desp):
    #if "分析仪状态从" != desp[0:6]:
    #    return desp
    for (cn, en) in replace_dic.items():
        desp = desp.replace(cn, en)
    return desp


def logaddsq(logfullpath, filter_col,
             log_days):  #log_days: log reserve days; 0 means all.
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf_16_le",
                        usecols=filter_col)
    tlog0 = tlog0.dropna(
        subset=["sCode", "dateTime", "eType", "funcArea", "sDescription"])
    log_gen_time = pd.to_datetime(tlog0.iloc[-1, 2])
    #筛选掉无用数据
    tlog0 = tlog0[(tlog0.funcArea.isin(Filter_List_funcArea))
                  & (tlog0.eType.isin(Filter_List_eType))]
    tlog0["sDescription"] = tlog0["sDescription"].apply(replace_desp)
    tlog0 = tlog0[(tlog0.eType == "ERROR")
                  | ((tlog0.eType == "INFORMATION")
                     & (tlog0.sDescription.isin(Filter_List_sDescription)))]
    tlog0 = tlog0[~tlog0.sCode.isin(Filter_List_sCode)]
    tlog0.reset_index(drop=True, inplace=True)
    tlog1 = cp.copy(tlog0)
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    if log_days != 0:
        logwithsq["log_days"] = (log_gen_time - pd.to_datetime(
            logwithsq["dateTime_x"])) / pd.Timedelta(1, "d") - log_days < 0
        logwithsq = logwithsq[logwithsq.log_days == True]
    return logwithsq


loglist = file_filter(logpath, ".txt")
for i in range(len(loglist)):
    print("Starting load file :{}".format(i + 1))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter,
                       peroid)  #peroid: log reserve days; 0 means all.
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
        "sFilename_x": "sFilename",
        "nSubCode_x": "nSubCode",
        "eCPU_x": "eCPU",
        "sCode_y": "sCodeSQ",
        "eType_y": "eTypeSQ",
        "dateTime_y": "dateTimeSQ",
        "funcArea_y": "funcAreaSQ",
        "sDescription_y": "sDescriptionSQ",
        "sFilename_y": "sFilenameSQ",
        "nSubCode_y": "nSubCodeSQ",
        "eCPU_y": "eCPUSQ"
    })
logonefile["Timediff"] = (
    pd.to_datetime(logonefile["dateTimeSQ"]) -
    pd.to_datetime(logonefile["dateTime"])) / pd.Timedelta(1, "S")
logonefile["Timediff<10s"] = logonefile["Timediff"].apply(lambda x: "Y"
                                                          if x < 10 else "N")
logonefile.drop([
    "eTypeSQ", "funcAreaSQ", "dateTimeSQ", "sFilenameSQ", "nSubCodeSQ",
    "eCPUSQ"
],
                axis=1,
                inplace=True)
logonefile.insert(0, "TopSn", logonefile.pop("TopSn"))
logonefile["log_days"] = peroid
logonefile.to_csv((logpath + "\\one.csv"),
                  index_label="Index",
                  encoding="utf_8")
print("Done")

print(dt.datetime.now() - start)
