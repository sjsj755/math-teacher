# -*- coding: utf-8 -*-
"""内容一致性校验脚本（发布前测试基线之一）。

校验 math_up_app/assets/data/ 下的章节树、题库与内容索引：
- id 唯一、编码存在且无悬空引用；
- 字段枚举合法（type / difficulty / lose_type / thinking_method）；
- answer 合法性（选择题 A-D、填空/解答题非空、自评题可空）；
- 每个知识点 3-5 题、总量 50-80、每章至少 1 道难度 4-5 的压轴题；
- 输出难度分布统计。

用法：python scripts/validate_content.py
失败时退出码非 0。
"""

import collections
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "math_up_app" / "assets" / "data"

QUESTION_TYPES = {"choice", "fill", "essay", "self_s", "self_p"}
LOSE_TYPES = {"knowledge", "method", "calculation", "standard", "psychology"}
THINKING_METHODS = {
    "函数与方程",
    "数形结合",
    "分类讨论",
    "转化与化归",
    "特殊与一般",
    "有限与无限",
    "整体与局部",
    "或然与必然",
}
CONTENT_CHAPTERS = {"A1-1", "A1-2", "A1-3", "A1-4", "A1-5"}


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    errors = []
    warnings = []

    index = load_json(DATA / "content_index.json")
    chapters = load_json(DATA / "chapters.json")
    questions = load_json(DATA / "questions.json")["questions"]
    config = load_json(DATA / "config.json")

    content_version = index.get("content_version")
    if not isinstance(content_version, int) or content_version < 1:
        errors.append("content_index.json: content_version 必须为正整数")

    # ---- 配置 ----
    diagnosis = config.get("diagnosis") or {}
    for key in ("total", "k", "t", "s", "p"):
        if not isinstance(diagnosis.get(key), int) or diagnosis.get(key) <= 0:
            errors.append(f"config.json: diagnosis.{key} 必须为正整数")
    if diagnosis.get("total") != diagnosis.get("k") + diagnosis.get("t") + diagnosis.get("s") + diagnosis.get("p"):
        errors.append("config.json: diagnosis.total 必须等于 k+t+s+p")
    weak = diagnosis.get("weak_threshold")
    if not isinstance(weak, (int, float)) or not 0 < weak < 1:
        errors.append("config.json: diagnosis.weak_threshold 必须在 (0,1) 内")
    timing = config.get("timing") or {}
    for key in ("choice", "fill", "essay"):
        if not isinstance(timing.get(key), int) or timing.get(key) <= 0:
            errors.append(f"config.json: timing.{key} 必须为正整数")
    practice = config.get("practice") or {}
    if not isinstance(practice.get("size"), int) or practice.get("size") <= 0:
        errors.append("config.json: practice.size 必须为正整数")

    # ---- 章节树 ----
    books = chapters.get("books")
    if not isinstance(books, list) or len(books) != 5:
        errors.append(f"chapters.json: 应有 5 册，实际 {len(books) if isinstance(books, list) else '缺失'}")
    book_ids = set()
    chapter_ids = set()
    section_ids = set()
    for book in books or []:
        bid = book.get("id")
        if not bid or bid in book_ids:
            errors.append(f"chapters.json: 册 id 缺失或重复：{bid}")
        book_ids.add(bid)
        grades = book.get("grades") or []
        if bid in {"A1", "A2"} and "高一" not in grades:
            errors.append(f"chapters.json: {bid} 应标记高一")
        if bid in {"B1", "B2", "B3"} and "高二" not in grades:
            errors.append(f"chapters.json: {bid} 应标记高二")
        for chapter in book.get("chapters") or []:
            cid = chapter.get("id")
            if not cid or cid in chapter_ids:
                errors.append(f"chapters.json: 章 id 缺失或重复：{cid}")
            elif not cid.startswith(bid + "-"):
                errors.append(f"chapters.json: 章 {cid} 前缀与册 {bid} 不一致")
            chapter_ids.add(cid)
            if not chapter.get("name") or not chapter.get("knowledge_points"):
                errors.append(f"chapters.json: 章 {cid} 缺少 name 或 knowledge_points")
            for section in chapter.get("sections") or []:
                sid = section.get("id")
                if not sid or sid in section_ids:
                    errors.append(f"chapters.json: 节 id 缺失或重复：{sid}")
                elif not sid.startswith(cid + "-"):
                    errors.append(f"chapters.json: 节 {sid} 前缀与章 {cid} 不一致")
                section_ids.add(sid)
                if not section.get("name"):
                    errors.append(f"chapters.json: 节 {sid} 缺少 name")

    if len(chapter_ids) != 18:
        errors.append(f"chapters.json: 应有 18 章，实际 {len(chapter_ids)}")

    expected_sections = index.get("stats", {}).get("sections")
    if expected_sections is not None and len(section_ids) != expected_sections:
        errors.append(f"content_index.json: sections 统计 {expected_sections} 与实际 {len(section_ids)} 不一致")

    # ---- 题库 ----
    qids = set()
    type_count = collections.Counter()
    content_difficulty_count = collections.Counter()
    per_variant = collections.Counter()
    per_chapter_d4 = collections.Counter()
    content_questions = 0

    for q in questions:
        qid = q.get("id")
        if not qid:
            errors.append("questions.json: 存在缺少 id 的题目")
        elif qid in qids:
            errors.append(f"questions.json: 题目 id 重复：{qid}")
        qids.add(qid)

        qtype = q.get("type")
        if qtype not in QUESTION_TYPES:
            errors.append(f"{qid}: type 非法：{qtype}")
        type_count[qtype] += 1

        difficulty = q.get("difficulty")
        if not isinstance(difficulty, int) or not 1 <= difficulty <= 5:
            errors.append(f"{qid}: difficulty 非法：{difficulty}")

        lose = q.get("lose_type")
        if lose not in LOSE_TYPES:
            errors.append(f"{qid}: lose_type 非法：{lose}")

        is_timed = q.get("is_timed", False)
        if not isinstance(is_timed, bool):
            errors.append(f"{qid}: is_timed 必须为布尔值")
        if is_timed and qtype != "choice":
            errors.append(f"{qid}: 限时题（is_timed）仅允许选择题")

        method = q.get("thinking_method")
        if method is not None and method not in THINKING_METHODS:
            errors.append(f"{qid}: thinking_method 非法：{method}")
        if difficulty is not None and difficulty >= 3 and qtype in {"choice", "fill", "essay"} and not method:
            errors.append(f"{qid}: 中档及以上题目必须标注 thinking_method")

        chapter = q.get("chapter")
        variant = q.get("variant_group")
        if chapter != "DIAG" and chapter not in chapter_ids:
            errors.append(f"{qid}: 章节编码 {chapter} 不存在于章节树")
        if not (variant and (variant in section_ids or variant.startswith("DIAG-"))):
            errors.append(f"{qid}: variant_group {variant} 悬空（不在章节树中，也非 DIAG 组）")

        if not q.get("stem"):
            errors.append(f"{qid}: stem 为空")
        if not q.get("knowledge_point"):
            errors.append(f"{qid}: knowledge_point 为空")

        options = q.get("options") or []
        answer = q.get("answer") or ""
        if qtype == "choice":
            if len(options) != 4:
                errors.append(f"{qid}: choice 题必须恰好 4 个选项，实际 {len(options)}")
            if answer not in {"A", "B", "C", "D"}:
                errors.append(f"{qid}: choice 题 answer 必须为 A-D，实际 {answer}")
        elif qtype in {"fill", "essay"}:
            if not answer.strip():
                errors.append(f"{qid}: {qtype} 题 answer 不能为空")
        elif qtype in {"self_s", "self_p"}:
            if len(options) < 2:
                errors.append(f"{qid}: 自评题至少需要 2 个选项")

        if chapter in CONTENT_CHAPTERS:
            content_questions += 1
            content_difficulty_count[difficulty] += 1
            per_variant[variant] += 1
            if difficulty is not None and difficulty >= 4:
                per_chapter_d4[chapter] += 1

    if not 50 <= content_questions <= 80:
        errors.append(f"题库内容题总量应为 50-80，实际 {content_questions}")

    for variant, count in per_variant.items():
        if not 3 <= count <= 5:
            errors.append(f"知识点 {variant} 应有 3-5 题，实际 {count}")

    for chapter in sorted(CONTENT_CHAPTERS):
        if per_chapter_d4[chapter] < 1:
            errors.append(f"章节 {chapter} 缺少难度 4-5 的压轴题")

    timed_pool = [q for q in questions if q.get("is_timed") is True]
    if not timed_pool:
        errors.append("questions.json: 限时题池为空，至少需要 1 道 is_timed 选择题")

    # ---- 统计输出 ----
    content_total = sum(content_difficulty_count.values())
    if content_total > 0:
        base = (content_difficulty_count[1] + content_difficulty_count[2]) / content_total * 100
        mid = content_difficulty_count[3] / content_total * 100
        hard = (content_difficulty_count[4] + content_difficulty_count[5]) / content_total * 100
        print(f"内容题难度分布：基础(1-2) {base:.1f}% / 中档(3) {mid:.1f}% / 压轴(4-5) {hard:.1f}%")
        if not 50 <= base <= 70:
            warnings.append(f"基础题占比 {base:.1f}% 偏离建议范围 50-70%")
        if not 20 <= mid <= 40:
            warnings.append(f"中档题占比 {mid:.1f}% 偏离建议范围 20-40%")
        if not 5 <= hard <= 15:
            warnings.append(f"压轴题占比 {hard:.1f}% 偏离建议范围 5-15%")

    print(
        f"统计：题目 {len(questions)}（内容 {content_questions}，自评 "
        f"{type_count['self_s'] + type_count['self_p']}），章节 {len(chapter_ids)}，节 {len(section_ids)}，"
        f"content_version {content_version}"
    )
    for w in warnings:
        print(f"警告：{w}")

    if errors:
        for e in errors:
            print(f"错误：{e}", file=sys.stderr)
        print(f"校验失败：共 {len(errors)} 个错误", file=sys.stderr)
        return 1

    print("校验通过：章节树与题库一致，无悬空编码。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
