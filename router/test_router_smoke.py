"""Task Router 烟测 — 验证每个 alias 真能调通。"""
import sys
sys.path.insert(0, "/home/cx/infra")

from router.task_router import route_chat, list_tasks, TASK_MAP

FAILURES = []
PASSED = []


def test(task: str) -> None:
    spec = TASK_MAP[task]
    print(f"  test {task:14s} (alias={spec.alias}) ...", end=" ")
    try:
        resp = route_chat(
            task=task,
            messages=[{"role": "user", "content": "reply with just: hi"}],
            max_tokens=300,  # 覆盖默认，节省 token
        )
        content = resp["choices"][0]["message"]["content"]
        if len(content) > 0 and resp["usage"]:
            print(f"OK ({len(content)} chars)")
            PASSED.append(task)
        else:
            print(f"FAIL: empty content")
            FAILURES.append((task, "empty"))
    except Exception as e:
        # 别的不通最常见：alias 没配 key (4 个有 key 的 alias 之外会 fail)
        print(f"SKIP: {type(e).__name__}: {str(e)[:80]}")
        FAILURES.append((task, str(e)[:80]))


if __name__ == "__main__":
    print(f"=== Task Router Smoke Test ===")
    print(f"  Litellm gateway: http://localhost:4000")
    print(f"  Tasks registered: {len(list_tasks())}")
    print()

    # 测默认任务 + 当前可能通的 alias
    for task in ["review", "summarize", "code", "architecture", "translate", "default"]:
        test(task)

    print()
    print(f"=== Result: {len(PASSED)} passed, {len(FAILURES)} failed/skipped ===")
    if FAILURES:
        print("Failed:")
        for t, err in FAILURES:
            print(f"  - {t}: {err}")
