1# Modify 2021/09/08 09:16

import pandas as pd
import os
import datetime as dt
import tkinter.filedialog as tk
import tkinter

while True:
    select_input = input(
        "How to Get Work Path:\n1 : Current Folder\n2 : Select one\n>>:")
    if select_input == "1":
        logpath = os.path.split(os.path.abspath(__file__))[0] + "\\GeneralLogs"
        break
    elif select_input == "2":
        root = tkinter.Tk()
        root.withdraw()
        logpath = tk.askdirectory()
        break
    else:
        print("Input 1 or 2")

peroid = 200  # log reserve days; 0 means all.
dropHeadTail = False  # 是否去除首尾两月数据,默认不去
lightMode = False  # 是否删除ES/IES之外的所有纪录

fileLine = {} # 文件行数空字典

keepDays = "wholeLogs" if peroid == 0 else peroid

print("\n")
print("*" * 150)
print("Log working folder>>:")
print(logpath)
print(f"保留的日志天数：{keepDays}")
print(f"去除首尾两月：{dropHeadTail}")
print(f"精简的日志: {lightMode}")
print("*" * 150)
os.system("pause")
start = dt.datetime.now()

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
# Selected sDescription list
'''
"Analyzer Status changed from Busy to Ready."
"Analyzer Status changed from Ready to Busy."
"Analyzer Status changed from Ready to Maintenance."
"Analyzer Status changed from Maintenance to Ready."
"Analyzer Status changed from Busy to Controlled stop."
"Analyzer Status changed from Controlled stop to Busy."
"Analyzer Status changed from Ready to Initializing."
"Analyzer Status changed from Not connected to Power up."
"Analyzer Status changed from Power up to Initializing."
"Analyzer Status changed from Initializing to Adjusting thermal."
"Analyzer Status changed from Adjusting thermal to Ready."
"Analyzer Status changed from Maintenance to Error."
"Analyzer Status changed from Error to Emergency stop."
"Analyzer Status changed from Emergency stop to Not connected."
"Analyzer Status changed from Ready to Error."
"Analyzer Status changed from Error to Ready."
"Analyzer Status changed from Ready to Emergency stop."
"Analyzer Status changed from Error to Maintenance."
"Analyzer Status changed from Controlled stop to Error."
"Analyzer Status changed from Ready to Diagnostics."
"Analyzer Status changed from Diagnostics to Emergency stop."
"Analyzer Status changed from Initializing to Error."
"Analyzer Status changed from Busy to Emergency stop."
"Analyzer Status changed from Error to Initializing."
"Analyzer Status changed from Not connected to Error."
"Analyzer Status changed from Error to Not connected."
"Analyzer Status changed from Power up to Diagnostics."
"Analyzer Status changed from Adjusting thermal to Error."
"Analyzer Status changed from Error to Adjusting thermal."
"Analyzer Status changed from Not connected to Emergency stop."
"Analyzer Status changed from Initializing to Ready."
"Analyzer Status changed from Maintenance to Emergency stop."
"Analyzer Status changed from Initializing to Emergency stop."
"Analyzer Status changed from Power up to Emergency stop."
"Analyzer Status changed from Power up to Error."
"Analyzer Status changed from Error to Power up."
"Analyzer Status changed from Error to Diagnostics."
"Analyzer Status changed from Controlled stop to Emergency stop."
"Analyzer Status changed from Controlled stop to Ready."
"Analyzer Status changed from Adjusting thermal to Emergency stop."
'''
Filter_List_sDescription = [
    "Analyzer Status changed from Busy to Emergency stop.",
    "Analyzer Status changed from Busy to Controlled stop.",
    "Analyzer Status changed from Controlled stop to Emergency stop.",
    "Analyzer Status changed from Initializing to Emergency stop.",
    "Analyzer Status changed from Initializing to Error.",
    "Analyzer Status changed from Maintenance to Emergency stop.",
    "Analyzer Status changed from Maintenance to Error.",
    "timeFlag"
]

# Unselected sCode list
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

# Selected funcArea/eType list
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
    # if "分析仪状态从" != desp[0:6]:
    #    return desp
    for (cn, en) in replace_dic.items():
        desp = desp.replace(cn, en)
    return desp


def logaddsq(logfullpath, filter_col,
             log_days, selt_index):  # log_days: log reserve days; 0 means all.
    print("Starting load file :{}".format(selt_index + 1))
    print(logfullpath)
    tlog0 = pd.read_csv(logfullpath,
                        sep="\t",
                        encoding="utf_16_le",
                        usecols=filter_col)
    log_gen_time = pd.to_datetime(tlog0.iloc[-1, 2])
    fileLine[logfullpath] = [len(tlog0),log_gen_time]
    tlog0 = tlog0.dropna(
        subset=["sCode", "dateTime", "eType", "funcArea", "sDescription"])
    # 去除首尾两月数据
    if dropHeadTail:
        tlog0["year_month"] = tlog0["dateTime"].astype("str").str[0:7]
        start_month, end_month = tlog0.iloc[1, 8], tlog0.iloc[-1, 8]
        tlog0 = tlog0[tlog0.year_month != start_month]  # 去除首月
        tlog0 = tlog0[tlog0.year_month != end_month]  # 去除尾月
        tlog0.drop(["year_month"], axis=1, inplace=True)
    # 筛选掉无用数据
    tlog0 = tlog0[(tlog0.funcArea.isin(Filter_List_funcArea))
                  & (tlog0.eType.isin(Filter_List_eType))]
    tlog0["sDescription"] = tlog0["sDescription"].apply(replace_desp)
    tlog0 = tlog0[(tlog0.eType == "ERROR")
                  | ((tlog0.eType == "INFORMATION")
                     & (tlog0.sDescription.isin(Filter_List_sDescription)))]
    tlog0 = tlog0[~tlog0.sCode.isin(Filter_List_sCode)]
    tlog0 = pd.concat([tlog0,pd.DataFrame({"sCode": ["timeFlag", "timeFlag"],
                                       "dateTime": [log_gen_time, log_gen_time],
                                       "eType": ["ERROR", "ERROR"],
                                       "funcArea": ["timeFlag", "timeFlag"],
                                       "sDescription": ["timeFlag", "timeFlag"],
                                       "sFilename": ["timeFlag", "timeFlag"],
                                       "nSubCode": ["timeFlag", "timeFlag"],
                                       "eCPU": ["timeFlag", "timeFlag"]})])
    tlog0.reset_index(drop=True, inplace=True)
    tlog1 = tlog0.copy()
    tlog1.index = tlog1.index + 1
    logwithsq = pd.merge(tlog1, tlog0, left_index=True, right_index=True)
    # 保留参数指定天数的日志
    if log_days != 0:
        logwithsq["log_days"] = (log_gen_time - pd.to_datetime(
            logwithsq["dateTime_x"])) / pd.Timedelta(1, "d") - log_days < 0
        logwithsq = logwithsq[logwithsq.log_days == True]
    if "J.txt" in logfullpath or "j.txt" in logfullpath:
        logwithsq["TopSn"] = logfullpath[-14:-4]
    else:
        logwithsq["TopSn"] = logfullpath[-13:-4]
    return logwithsq


loglist = file_filter(logpath, ".txt")
logonefile = [logaddsq((logpath + "\\" + loglist[i]), colfilter,
                       peroid, i) for i in range(len(loglist))]
logonefile = pd.concat(logonefile)

"""
for i in range(len(loglist)):
    print("Starting load file :{}".format(i + 1))
    logtemp = logaddsq((logpath + "\\" + loglist[i]), colfilter,
                       peroid)  # peroid: log reserve days; 0 means all.
    if i == 0:
        logonefile = logtemp
        continue
    logonefile = pd.concat([logonefile, logtemp])
"""
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
logonefile["Timediff<2s"] = logonefile["Timediff"].apply(lambda x: "Y"
                                                         if x < 2 else "N")
logonefile.drop(["eTypeSQ", "funcAreaSQ", "dateTimeSQ", "sFilenameSQ", "nSubCodeSQ", "eCPUSQ"],
                axis=1,
                inplace=True)
logonefile.insert(0, "TopSn", logonefile.pop("TopSn"))
logonefile["log_days"] = peroid

if lightMode == True:
    logonefile = logonefile[(logonefile.sDescriptionSQ.isin(
        Filter_List_sDescription)) & (logonefile["Timediff<2s"] == "Y")]
logonefile.reset_index(drop=True, inplace=True)
logonefile.to_csv((logpath + "\\one.csv"),
                  index_label="Index",
                  encoding="utf_8")
print("Done")

print(dt.datetime.now() - start)

fileSeries = pd.Series(fileLine)
fileSeries.to_csv(logpath + "\\fileLine.csv")

os.system("pause")
