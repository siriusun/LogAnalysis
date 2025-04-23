# -*- coding: utf-8 -*-
"""
TopLog ETL 脚本 - 用于处理医疗分析仪器日志数据
功能: 读取、清洗、转换并加载日志数据到CSV和PostgreSQL数据库
已优化: 使用多进程并行处理日志文件
对于HemoCELL: PERIOD = 60, 对于TOPStandalone: PERIOD = 0

修改日期: 2025-04-22
"""

import pandas as pd
import os
import datetime as dt
import tkinter.filedialog as tk
import tkinter
import chardet
import psycopg as pg
from dateutil.relativedelta import relativedelta
import concurrent.futures
import numpy as np

# =================== 配置部分 ===================
# 日志保留天数: 0表示保留所有日志
PERIOD = 0
# 是否去除首尾两月数据
DROP_HEAD_TAIL = False
# 是否删除ES/IES之外的所有记录（轻量模式）
LIGHT_MODE = False
# 日志列过滤器
COLUMN_FILTER = [
    "sCode",
    "eType",
    "dateTime",
    "funcArea",
    "sDescription",
    "sFilename",
    "nSubCode",
    "eCPU",
]
# 中英文状态描述转换字典
REPLACE_DICT = {
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
    "试剂2": "REAGENT 2",
}
# 保留的状态描述列表
FILTER_LIST_SDESCRIPTION = [
    "Analyzer Status changed from Busy to Emergency stop.",
    "Analyzer Status changed from Busy to Controlled stop.",
    "Analyzer Status changed from Controlled stop to Error.",
    "Analyzer Status changed from Controlled stop to Emergency stop.",
    "Analyzer Status changed from Initializing to Emergency stop.",
    "Analyzer Status changed from Initializing to Error.",
    "Analyzer Status changed from Maintenance to Emergency stop.",
    "Analyzer Status changed from Maintenance to Error.",
    "timeFlag",
]
# 排除的错误代码列表
UNSELECT_LIST_SCODE = [
    "'03218",
    "'03004",
    "'02083",
    "'02025",
    "'03215",
    "'03188",
    "'02055",
    "'03184",
    "'01285",
    "'01336",
    "'02077",
    "'03007",
    "'03014",
    "'00056",
    "'03013",
    "'03084",
    "'03016",
    "'03085",
    "'03211",
    "'03020",
    "'03019",
    "'03005",
    "'03011",
    "'03018",
    "'03015",
    "'03017",
    "'03009",
    "'03010",
    "'03021",
]
# 过滤的功能区域
FILTER_LIST_FUNCAREA = ["Analyzer", "Materials"]
# 过滤的事件类型
FILTER_LIST_ETYPE = ["ERROR", "INFORMATION"]
# 数据库连接信息
DB_CONFIG = {
    "dbname": "mydb",
    "user": "sirius",
    "password": "biicf",
    "host": "localhost",
}
# 多进程设置 - 进程创建开销较大，减少进程数量
MAX_WORKERS = max(1, os.cpu_count() - 1)  # 留出1个CPU核心给系统


# =================== 函数定义 ===================
def get_work_path():
    """获取工作路径, 允许用户选择当前文件夹或手动选择"""
    while True:
        select_input = input("如何获取工作路径:\n1 : 当前文件夹\n2 : 手动选择\n>>:")
        if select_input == "1":
            return os.path.join(
                os.path.split(os.path.abspath(__file__))[0], "GeneralLogs"
            )
        elif select_input == "2":
            root = tkinter.Tk()
            root.withdraw()
            return tk.askdirectory()
        else:
            print("请输入 1 或 2")


def print_config_info(log_path, period):
    """打印配置信息"""
    keep_days = "所有日志" if period == 0 else period
    print("\n" + "*" * 150)
    print("日志工作文件夹>>:")
    print(log_path)
    print(f"保留的日志天数: {keep_days}")
    print(f"去除首尾两月: {DROP_HEAD_TAIL}")
    print(f"精简的日志: {LIGHT_MODE}")
    print(f"使用进程数: {MAX_WORKERS}")
    print("*" * 150)
    os.system("pause")


def file_filter(file_dir, keyword):
    """根据关键字筛选文件"""
    try:
        all_files = os.listdir(file_dir)
        return [file for file in all_files if keyword in file]
    except Exception as e:
        print(f"文件筛选出错: {e}")
        return []


def replace_description(description):
    """将中文状态描述转换为英文"""
    if "分析仪状态从" not in description:
        return description

    for cn, en in REPLACE_DICT.items():
        description = description.replace(cn, en)
    return description


def detect_file_encoding(file_path):
    """检测文件编码"""
    try:
        with open(file_path, "rb") as file:
            content = file.read()
        code_dict = chardet.detect(content)
        return code_dict["encoding"]
    except Exception as e:
        print(f"检测文件编码出错: {e}")
        return "utf-8"  # 默认编码


def process_log_file(log_file, log_path, filter_col, log_days, encoding):
    """处理单个日志文件（进程安全）"""
    full_path = os.path.join(log_path, log_file)
    print(f"处理文件: {full_path}")

    try:
        # 读取日志文件
        df = pd.read_csv(
            full_path,
            sep="\t",
            encoding=encoding,
            usecols=filter_col,
            parse_dates=["dateTime"],
        )

        # 检查数据框是否为空
        if df.empty:
            print(f"警告: {full_path} 是空文件或未包含所需列")
            return None

        # 确保日期时间格式正确
        if df["dateTime"].dtype != "datetime64[ns]":
            df["dateTime"] = pd.to_datetime(df["dateTime"], errors="coerce")
            df = df.dropna(subset=["dateTime"])
            if df.shape[0] == 0:
                print(f"警告: {full_path} 中没有有效的日期时间数据")
                return None

        # 记录日志生成时间
        log_gen_time = pd.to_datetime(df.iloc[-1, 2])

        # 删除空值记录
        df = df.dropna(
            subset=["sCode", "dateTime", "eType", "funcArea", "sDescription"]
        )

        # 去除首尾两月数据（如果启用）
        if DROP_HEAD_TAIL:
            df["year_month"] = df["dateTime"].dt.strftime("%Y%m")
            start_month, end_month = df["year_month"].iloc[0], df["year_month"].iloc[-1]
            df = df[df.year_month != start_month]  # 去除首月
            df = df[df.year_month != end_month]  # 去除尾月
            df.drop(["year_month"], axis=1, inplace=True)

        # 应用过滤条件
        df = df[
            (df.funcArea.isin(FILTER_LIST_FUNCAREA))
            & (df.eType.isin(FILTER_LIST_ETYPE))
        ]

        # 转换状态描述
        df["sDescription"] = df["sDescription"].map(replace_description)

        # 进一步过滤
        df = df[
            (df.eType == "ERROR") | (df.sDescription.isin(FILTER_LIST_SDESCRIPTION))
        ]
        df = df[~df.sCode.isin(UNSELECT_LIST_SCODE)]

        # 添加时间标记
        time_flag_df = pd.DataFrame(
            {
                "sCode": ["timeFlag", "timeFlag"],
                "dateTime": [log_gen_time, log_gen_time],
                "eType": ["ERROR", "ERROR"],
                "funcArea": ["timeFlag", "timeFlag"],
                "sDescription": ["timeFlag", "timeFlag"],
                "sFilename": ["timeFlag", "timeFlag"],
                "nSubCode": ["timeFlag", "timeFlag"],
                "eCPU": ["timeFlag", "timeFlag"],
            }
        )
        df = pd.concat(
            [df, time_flag_df], ignore_index=True
        )  # ***ignore_index=True 重置索引, 非常重要, 直接影响后面的merge操作***

        # 创建带序列的复制数据
        df_copy = df.copy()
        df.drop(
            ["eType", "funcArea", "sFilename", "nSubCode", "eCPU"], axis=1, inplace=True
        )
        df_copy.index = df_copy.index + 1

        # 合并数据以创建顺序关系
        log_with_seq = pd.merge(
            df_copy, df, left_index=True, right_index=True, suffixes=("", "SQ")
        )

        # 如果需要, 仅保留指定天数的日志
        if log_days != 0:
            log_with_seq["log_days"] = (
                log_gen_time - pd.to_datetime(log_with_seq["dateTime"])
            ) / pd.Timedelta("1d") - log_days < 0
            log_with_seq = log_with_seq[log_with_seq.log_days]

        # 添加TopSn列
        log_with_seq["TopSn"] = "T" + log_file.split("_")[0]

        return log_with_seq

    except Exception as e:
        print(f"处理文件 {full_path} 时出错: {e}")
        return None


def get_target_month():
    """获取目标月份"""
    # 计算上个月的月份
    current_date = dt.datetime.today()
    previous_month = (current_date - relativedelta(months=1)).strftime("%Y%m")

    print("\n" + "-" * 50)
    print("请选择数据筛选方式:")
    print("1 : 插入所有数据")
    print("2 : 插入上月数据, 月份", previous_month)
    print("3 : 手动输入月份, 格式 yyyymm")
    print("-" * 50)

    while True:
        user_choice = input("请输入选择(1-3)>>: ")

        if user_choice == "1":
            return "ALL"  # 特殊标记, 表示全部数据
        elif user_choice == "2":
            return previous_month
        elif user_choice == "3":
            month_input = input("请输入月份, 格式 yyyymm: ")
            # 简单验证输入的月份格式
            if len(month_input) == 6 and month_input.isdigit():
                return month_input
            else:
                print("月份格式错误, 请重新输入！")
        else:
            print("输入错误, 请输入1、2或3")


def save_to_database(df, db_config):
    """保存数据到PostgreSQL数据库"""
    try:
        # 连接数据库
        conn = pg.connect(
            dbname=db_config["dbname"],
            user=db_config["user"],
            password=db_config["password"],
            host=db_config["host"],
        )
        cur = conn.cursor()

        # 开始批量插入
        rows_inserted = 0
        batch_size = 5000  # 设置合适的批处理大小
        total_rows = len(df)

        # 创建批处理数据
        batches = [
            df.iloc[i : i + batch_size] for i in range(0, total_rows, batch_size)
        ]

        for batch in batches:
            # 准备批量插入数据
            values = []
            for _, row in batch.iterrows():
                values.append(
                    (
                        row["TopSn"],
                        row["sCode"],
                        row["eType"],
                        row["dateTime"],
                        row["funcArea"],
                        row["sDescription"],
                        row["sFilename"],
                        row["nSubCode"],
                        row["eCPU"],
                        row["sCodeSQ"],
                        row["sDescriptionSQ"],
                        row["Timediff"],
                        row["Timediff<2s"],
                    )
                )

            # 使用executemany进行批量插入
            try:
                cur.executemany(
                    """
                    INSERT INTO service.topsta_genlog 
                    (topsn, scode, etype, datetime, funcarea, sdesc, filename, subcode, ecpu, 
                    scodesq, sdescsq, timediff, timediff2s) 
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) 
                    ON CONFLICT DO NOTHING
                    """,
                    values,
                )
                rows_inserted += len(batch)
                print(f"已处理 {rows_inserted}/{total_rows} 行数据")
            except Exception as e:
                print(f"批量插入数据出错: {e}")
                # 回退到逐条插入
                for _, row in batch.iterrows():
                    try:
                        cur.execute(
                            """
                            INSERT INTO service.topsta_genlog 
                            (topsn, scode, etype, datetime, funcarea, sdesc, filename, subcode, ecpu, 
                            scodesq, sdescsq, timediff, timediff2s) 
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) 
                            ON CONFLICT DO NOTHING
                            """,
                            (
                                row["TopSn"],
                                row["sCode"],
                                row["eType"],
                                row["dateTime"],
                                row["funcArea"],
                                row["sDescription"],
                                row["sFilename"],
                                row["nSubCode"],
                                row["eCPU"],
                                row["sCodeSQ"],
                                row["sDescriptionSQ"],
                                row["Timediff"],
                                row["Timediff<2s"],
                            ),
                        )
                        rows_inserted += 1
                    except Exception as e2:
                        print(f"插入行数据出错: {e2}")
                        continue

        # 提交事务并关闭连接
        conn.commit()
        cur.close()
        conn.close()

        print(f"成功插入 {rows_inserted} 行数据到数据库")
        return True

    except Exception as e:
        print(f"数据库操作出错: {e}")
        return False


# =================== 主程序 ===================
def main():
    """主程序入口"""
    try:
        # 获取工作路径
        log_path = get_work_path()

        # 打印配置信息
        print_config_info(log_path, PERIOD)

        # 记录开始时间
        start_time = dt.datetime.now()

        # 获取日志文件列表
        log_files = file_filter(log_path, ".txt")
        if not log_files:
            print("未找到日志文件")
            os.system("pause")
            return

        # 检测编码
        first_log_path = os.path.join(log_path, log_files[0])
        log_encoding = detect_file_encoding(first_log_path)
        print(f"检测到编码: {log_encoding}")

        # 使用进程池并行处理文件
        processed_logs = []
        print(f"开始并行处理 {len(log_files)} 个文件, 使用 {MAX_WORKERS} 个进程...")

        with concurrent.futures.ProcessPoolExecutor(
            max_workers=MAX_WORKERS
        ) as executor:
            # 提交所有任务并获取future对象
            future_to_file = {
                executor.submit(
                    process_log_file,
                    log_file,
                    log_path,
                    COLUMN_FILTER,
                    PERIOD,
                    log_encoding,
                ): log_file
                for log_file in log_files
            }

            # 收集结果
            for i, future in enumerate(concurrent.futures.as_completed(future_to_file)):
                file_name = future_to_file[future]
                try:
                    log_df = future.result()
                    if log_df is not None:
                        processed_logs.append(log_df)
                    print(f"完成文件 {i + 1}/{len(log_files)}: {file_name}")
                except Exception as e:
                    print(f"处理文件 {file_name} 时出现错误: {e}")

        # 检查是否有处理成功的日志
        if not processed_logs:
            print("没有找到有效的日志数据")
            os.system("pause")
            return

        # 合并所有处理后的日志（这一步必须在所有文件处理完成后进行）
        print("合并所有处理后的日志...")
        combined_log = pd.concat(processed_logs, ignore_index=True)

        # 以下是合并后的处理步骤
        print("计算时间差并添加标记...")
        # 计算时间差
        combined_log["Timediff"] = (
            pd.to_datetime(combined_log["dateTimeSQ"])
            - pd.to_datetime(combined_log["dateTime"])
        ) / pd.Timedelta("1s")

        # 使用向量化操作替代apply lambda
        combined_log["Timediff<2s"] = np.where(combined_log["Timediff"] < 2, "Y", "N")

        # 重新组织列
        combined_log.drop(["dateTimeSQ"], axis=1, inplace=True)
        # combined_log.insert(0, "TopSn", combined_log.pop("TopSn"))
        # combined_log["log_days"] = PERIOD

        # 如果启用轻量模式, 进一步过滤数据
        if LIGHT_MODE:
            print("应用轻量模式过滤...")
            combined_log = combined_log[
                (combined_log.sDescriptionSQ.isin(FILTER_LIST_SDESCRIPTION))
                & (combined_log["Timediff<2s"] == "Y")
            ]

        # 重置索引并保存到CSV
        combined_log.reset_index(drop=True, inplace=True)
        # csv_path = os.path.join(log_path, "one.csv")
        # print(f"保存合并后的日志到: {csv_path}")
        # combined_log.to_csv(csv_path, index_label="Index", encoding="utf_8")

        # 记录处理时间
        processing_time = dt.datetime.now() - start_time
        print(f"处理完成, 耗时: {processing_time}")

        # 输出数据信息
        combined_log.info()

        # 获取目标月份并过滤数据
        target_month = get_target_month()

        # 根据用户选择决定是否进行月份筛选
        if target_month == "ALL":
            # 不筛选月份, 使用全部数据
            filtered_log = combined_log
            print("使用全部数据...")
        else:
            # 根据选择的月份筛选数据
            filtered_log = combined_log[
                combined_log["dateTime"].dt.strftime("%Y%m") == target_month
            ]
            print(f"筛选 {target_month} 月份的数据...")

        # 去重
        filtered_log = filtered_log.drop_duplicates(
            subset=["TopSn", "sCode", "dateTime"]
        )

        # 保存到数据库
        if not filtered_log.empty:
            print(f"准备将 {len(filtered_log)} 行数据保存到数据库...")
            save_to_database(filtered_log, DB_CONFIG)
            # filtered_log.to_csv("new.csv", encoding="utf_8")
        else:
            print("警告: 没有找到符合条件的数据")

        os.system("pause")

    except Exception as e:
        print(f"程序运行出错: {e}")
        os.system("pause")


if __name__ == "__main__":
    main()
