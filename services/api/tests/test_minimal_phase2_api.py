import tempfile
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app


def _create_task(client: TestClient, dam_type: str = "earthfill") -> str:
    project_resp = client.post(
        "/api/v1/projects",
        json={
            "reservoir_name": "test_reservoir",
            "dam_type": dam_type,
        },
    )
    assert project_resp.status_code == 200
    project_id = project_resp.json()["data"]["project_id"]

    payload = {
        "project_id": project_id,
        "reservoir_name": "test_reservoir",
        "dam_type": dam_type,
        "inspection_type": "routine",
        "inspection_date": "2026-04-11",
        "weather": "sunny",
        "inspectors": ["tester"],
        "water_level": 120.5,
        "storage": 5000000,
        "hub_main_structures": "dam, spillway",
        "flood_protect_obj": "downstream village",
        "main_problem_desc": "",
        "enabled_chapters": ["A1", "A2", "A3", "A4"],
    }
    resp = client.post("/api/v1/tasks", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["success"] is True
    return body["data"]["task_id"]


def test_post_tasks_success() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        task_id = _create_task(client)
        assert task_id.startswith("task_")


def test_delete_task_success() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        task_id = _create_task(client)

        deleted = client.delete(f"/api/v1/tasks/{task_id}")
        assert deleted.status_code == 200
        assert deleted.json()["data"]["task_id"] == task_id

        listed = client.get("/api/v1/tasks")
        assert listed.status_code == 200
        ids = [x["task_id"] for x in listed.json()["data"]["items"]]
        assert task_id not in ids


def test_project_and_structure_instance_minimal_flow() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        created = client.post(
            "/api/v1/projects",
            json={
                "reservoir_name": "水库A",
                "dam_type": "earthfill",
            },
        )
        assert created.status_code == 200
        project_id = created.json()["data"]["project_id"]

        listed = client.get("/api/v1/projects")
        assert listed.status_code == 200
        listed_ids = [x["project_id"] for x in listed.json()["data"]["items"]]
        assert project_id in listed_ids

        detail = client.get(f"/api/v1/projects/{project_id}")
        assert detail.status_code == 200
        assert detail.json()["data"]["project_name"] == "水库A"

        batch = client.post(
            f"/api/v1/projects/{project_id}/structure-instances/batch-init",
            json={
                "presets": [
                    {"object_type": "main_dam", "count": 1},
                    {"object_type": "outlet_tunnel", "count": 2},
                ]
            },
        )
        assert batch.status_code == 200
        assert batch.json()["data"]["initialized_count"] == 3
        names = [x["instance_name"] for x in batch.json()["data"]["items"]]
        assert "大坝" in names

        batch_again = client.post(
            f"/api/v1/projects/{project_id}/structure-instances/batch-init",
            json={"presets": [{"object_type": "main_dam", "count": 1}]},
        )
        assert batch_again.status_code == 409

        templates = client.get("/api/v1/structure-part-templates", params={"object_type": "main_dam"})
        assert templates.status_code == 200
        assert templates.json()["data"]["items"][0]["part_name"] == "坝顶"


def test_delete_project_requires_no_tasks() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        created = client.post(
            "/api/v1/projects",
            json={"reservoir_name": "水库B", "dam_type": "earthfill"},
        )
        assert created.status_code == 200
        project_id = created.json()["data"]["project_id"]

        blocked = client.post(
            "/api/v1/tasks",
            json={
                "project_id": project_id,
                "reservoir_name": "水库B",
                "dam_type": "earthfill",
                "inspection_type": "routine",
                "inspection_date": "2026-04-11",
                "weather": "sunny",
                "inspectors": ["tester"],
                "enabled_chapters": ["A1", "A2"],
            },
        )
        assert blocked.status_code == 200

        not_allowed = client.delete(f"/api/v1/projects/{project_id}")
        assert not_allowed.status_code == 400

        task_id = blocked.json()["data"]["task_id"]
        removed_task = client.delete(f"/api/v1/tasks/{task_id}")
        assert removed_task.status_code == 200

        deleted = client.delete(f"/api/v1/projects/{project_id}")
        assert deleted.status_code == 200
        listed = client.get("/api/v1/projects")
        ids = [x["project_id"] for x in listed.json()["data"]["items"]]
        assert project_id not in ids


def test_archive_project_hidden_from_default_list() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        created = client.post(
            "/api/v1/projects",
            json={"reservoir_name": "水库C", "dam_type": "earthfill"},
        )
        assert created.status_code == 200
        project_id = created.json()["data"]["project_id"]

        archived = client.patch(f"/api/v1/projects/{project_id}/archive")
        assert archived.status_code == 200

        default_list = client.get("/api/v1/projects")
        assert default_list.status_code == 200
        default_ids = [x["project_id"] for x in default_list.json()["data"]["items"]]
        assert project_id not in default_ids

        archived_list = client.get("/api/v1/projects", params={"include_archived": "true"})
        assert archived_list.status_code == 200
        all_ids = [x["project_id"] for x in archived_list.json()["data"]["items"]]
        assert project_id in all_ids


def test_patch_project_success() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        created = client.post(
            "/api/v1/projects",
            json={"reservoir_name": "sample", "dam_type": "earthfill"},
        )
        assert created.status_code == 200
        project_id = created.json()["data"]["project_id"]

        updated = client.patch(
            f"/api/v1/projects/{project_id}",
            json={
                "reservoir_name": "sample-updated",
                "dam_type": "concrete",
                "description": "updated desc",
            },
        )
        assert updated.status_code == 200
        data = updated.json()["data"]
        assert data["reservoir_name"] == "sample-updated"
        assert data["project_name"] == "sample-updated"
        assert data["dam_type"] == "concrete"


def test_get_task_template_tree_a2_a3_switch_by_dam_type() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        earth_task = _create_task(client, dam_type="earthfill")
        earth_resp = client.get(f"/api/v1/tasks/{earth_task}/template-tree")
        assert earth_resp.status_code == 200
        earth_chapters = [x["chapter_code"] for x in earth_resp.json()["data"]]
        assert "A2" in earth_chapters
        assert "A3" not in earth_chapters

        concrete_task = _create_task(client, dam_type="concrete")
        concrete_resp = client.get(f"/api/v1/tasks/{concrete_task}/template-tree")
        assert concrete_resp.status_code == 200
        concrete_chapters = [x["chapter_code"] for x in concrete_resp.json()["data"]]
        assert "A3" in concrete_chapters
        assert "A2" not in concrete_chapters


def test_post_results_upsert_success() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        payload = {
            "task_id": task_id,
            "item_code": "A2_CREST_ROAD",
            "check_status": "abnormal",
            "issue_flag": True,
            "issue_type": ["crack"],
            "severity_level": "moderate",
            "check_record": "crack found",
            "suggestion": "recheck",
            "location_desc": "crest",
            "gps_lat": 26.1234,
            "gps_lng": 118.5678,
            "checked_at": "2026-04-11T09:30:00Z",
            "checked_by": "tester",
        }
        resp1 = client.post("/api/v1/results", json=payload)
        assert resp1.status_code == 200
        result_id_1 = resp1.json()["data"]["result_id"]

        payload["check_record"] = "crack verified"
        resp2 = client.post("/api/v1/results", json=payload)
        assert resp2.status_code == 200
        result_id_2 = resp2.json()["data"]["result_id"]
        assert result_id_1 == result_id_2


def test_get_task_results_with_filters() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A1_WEATHER",
                "check_status": "normal",
                "issue_flag": False,
                "issue_type": [],
                "severity_level": None,
                "check_record": "ok",
                "suggestion": "",
                "location_desc": "",
                "gps_lat": None,
                "gps_lng": None,
                "checked_at": "2026-04-11T09:30:00Z",
                "checked_by": "tester",
            },
        )
        client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A2_CREST_ROAD",
                "check_status": "abnormal",
                "issue_flag": True,
                "issue_type": ["crack"],
                "severity_level": "moderate",
                "check_record": "crack",
                "suggestion": "recheck",
                "location_desc": "crest",
                "gps_lat": 26.0,
                "gps_lng": 118.0,
                "checked_at": "2026-04-11T09:31:00Z",
                "checked_by": "tester",
            },
        )

        all_resp = client.get(f"/api/v1/tasks/{task_id}/results")
        assert all_resp.status_code == 200
        assert len(all_resp.json()["data"]["items"]) == 2

        ch_resp = client.get(f"/api/v1/tasks/{task_id}/results", params={"chapter_code": "A2"})
        assert ch_resp.status_code == 200
        ch_items = ch_resp.json()["data"]["items"]
        assert len(ch_items) == 1
        assert ch_items[0]["item_code"] == "A2_CREST_ROAD"

        issue_resp = client.get(f"/api/v1/tasks/{task_id}/results", params={"issue_flag": "true"})
        assert issue_resp.status_code == 200
        issue_items = issue_resp.json()["data"]["items"]
        assert len(issue_items) == 1
        assert issue_items[0]["issue_flag"] is True

        status_resp = client.get(f"/api/v1/tasks/{task_id}/results", params={"check_status": "normal"})
        assert status_resp.status_code == 200
        status_items = status_resp.json()["data"]["items"]
        assert len(status_items) == 1
        assert status_items[0]["check_status"] == "normal"


def test_get_task_progress_counts() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A1_WEATHER",
                "check_status": "normal",
                "issue_flag": False,
                "issue_type": [],
                "severity_level": None,
                "check_record": "ok",
                "suggestion": "",
                "location_desc": "",
                "gps_lat": None,
                "gps_lng": None,
                "checked_at": "2026-04-11T09:30:00Z",
                "checked_by": "tester",
            },
        )
        client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A2_CREST_ROAD",
                "check_status": "unchecked",
                "issue_flag": True,
                "issue_type": ["crack"],
                "severity_level": "minor",
                "check_record": "",
                "suggestion": "",
                "location_desc": "",
                "gps_lat": None,
                "gps_lng": None,
                "checked_at": "2026-04-11T09:31:00Z",
                "checked_by": "tester",
            },
        )

        resp = client.get(f"/api/v1/tasks/{task_id}/progress")
        assert resp.status_code == 200
        body = resp.json()["data"]
        assert body["overall"]["total"] == 67
        assert body["overall"]["completed"] == 1
        assert body["overall"]["percent"] == 1.5

        chapter_map = {c["chapter_code"]: c for c in body["chapters"]}
        assert chapter_map["A1"]["total"] == 10
        assert chapter_map["A1"]["completed"] == 1
        assert chapter_map["A1"]["issue_count"] == 0
        assert chapter_map["A2"]["total"] == 23
        assert chapter_map["A2"]["completed"] == 0
        assert chapter_map["A2"]["issue_count"] == 1


def test_evidence_upload_and_list() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        result_resp = client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A2_CREST_ROAD",
                "check_status": "abnormal",
                "issue_flag": True,
                "issue_type": ["crack"],
                "severity_level": "moderate",
                "check_record": "crack",
                "suggestion": "recheck",
                "location_desc": "crest",
                "gps_lat": 26.0,
                "gps_lng": 118.0,
                "checked_at": "2026-04-11T09:30:00Z",
                "checked_by": "tester",
            },
        )
        result_id = result_resp.json()["data"]["result_id"]

        upload = client.post(
            "/api/v1/evidence/upload",
            data={
                "result_id": result_id,
                "evidence_type": "photo",
                "caption": "crest photo",
                "gps_lat": "26.1234",
                "gps_lng": "118.5678",
                "shot_time": "2026-04-11T09:32:00Z",
            },
            files={"file": ("test.jpg", b"fake-jpg-content", "image/jpeg")},
        )
        assert upload.status_code == 200
        data = upload.json()["data"]
        assert data["evidence_id"].startswith("evi_")
        assert data["file_url"].startswith("/storage/evidence/")

        listed = client.get(f"/api/v1/results/{result_id}/evidence")
        assert listed.status_code == 200
        items = listed.json()["data"]["items"]
        assert len(items) == 1
        assert items[0]["evidence_type"] == "photo"
        assert items[0]["caption"] == "crest photo"

        result_list = client.get(f"/api/v1/tasks/{task_id}/results")
        assert result_list.status_code == 200
        assert result_list.json()["data"]["items"][0]["evidence_count"] == 1

        file_rel = data["file_url"].replace("/storage/", "")
        assert (Path(td) / file_rel).exists()


def test_evidence_delete_soft_delete_updates_views() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        result_resp = client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A2_CREST_ROAD",
                "check_status": "abnormal",
                "issue_flag": True,
                "issue_type": ["crack"],
                "severity_level": "moderate",
                "check_record": "crack",
                "suggestion": "recheck",
                "location_desc": "crest",
                "gps_lat": 26.0,
                "gps_lng": 118.0,
                "checked_at": "2026-04-11T09:30:00Z",
                "checked_by": "tester",
            },
        )
        result_id = result_resp.json()["data"]["result_id"]

        upload = client.post(
            "/api/v1/evidence/upload",
            data={
                "result_id": result_id,
                "evidence_type": "photo",
            },
            files={"file": ("to-delete.jpg", b"to-delete", "image/jpeg")},
        )
        assert upload.status_code == 200
        evidence_id = upload.json()["data"]["evidence_id"]

        before = client.get(f"/api/v1/tasks/{task_id}/results")
        assert before.status_code == 200
        assert before.json()["data"]["items"][0]["evidence_count"] == 1

        deleted = client.delete(f"/api/v1/evidence/{evidence_id}")
        assert deleted.status_code == 200
        assert deleted.json()["data"]["evidence_id"] == evidence_id

        listed = client.get(f"/api/v1/results/{result_id}/evidence")
        assert listed.status_code == 200
        assert listed.json()["data"]["items"] == []

        after = client.get(f"/api/v1/tasks/{task_id}/results")
        assert after.status_code == 200
        assert after.json()["data"]["items"][0]["evidence_count"] == 0


def test_export_issue_list_and_photo_sheet_csv() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)

        task_id = _create_task(client, dam_type="earthfill")
        result_resp = client.post(
            "/api/v1/results",
            json={
                "task_id": task_id,
                "item_code": "A2_CREST_ROAD",
                "check_status": "abnormal",
                "issue_flag": True,
                "issue_type": ["crack", "seepage"],
                "severity_level": "moderate",
                "check_record": "road crack and seepage",
                "suggestion": "repair and monitor",
                "location_desc": "crest road",
                "gps_lat": 26.1,
                "gps_lng": 118.2,
                "checked_at": "2026-04-11T09:30:00Z",
                "checked_by": "tester",
            },
        )
        assert result_resp.status_code == 200
        result_id = result_resp.json()["data"]["result_id"]

        upload_resp = client.post(
            "/api/v1/evidence/upload",
            data={
                "result_id": result_id,
                "evidence_type": "photo",
                "caption": "crest photo",
                "shot_time": "2026-04-11T09:35:00Z",
            },
            files={"file": ("photo.jpg", b"fake-photo", "image/jpeg")},
        )
        assert upload_resp.status_code == 200

        issue_export = client.get(f"/api/v1/tasks/{task_id}/exports/issues-list")
        assert issue_export.status_code == 200
        issue_data = issue_export.json()["data"]
        assert issue_data["format"] == "csv"
        assert issue_data["file_url"].startswith("/storage/exports/")
        issue_rel = issue_data["file_url"].replace("/storage/", "")
        issue_file = Path(td) / issue_rel
        assert issue_file.exists()
        issue_text = issue_file.read_text(encoding="utf-8-sig")
        assert "chapter_code,item_code,item_name,issue_type,severity_level,check_record,suggestion" in issue_text
        assert "A2_CREST_ROAD" in issue_text
        assert "crack,seepage" in issue_text

        photo_export = client.get(f"/api/v1/tasks/{task_id}/exports/photo-sheet")
        assert photo_export.status_code == 200
        photo_data = photo_export.json()["data"]
        assert photo_data["format"] == "csv"
        assert photo_data["file_url"].startswith("/storage/exports/")
        photo_rel = photo_data["file_url"].replace("/storage/", "")
        photo_file = Path(td) / photo_rel
        assert photo_file.exists()
        photo_text = photo_file.read_text(encoding="utf-8-sig")
        assert (
            "chapter_code,item_code,item_name,evidence_id,evidence_type,caption,shot_time,file_url"
            in photo_text
        )
        assert "A2_CREST_ROAD" in photo_text
        assert ",photo,crest photo," in photo_text


def test_capture_create_requires_text() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        task_id = _create_task(client, dam_type="earthfill")

        bad = client.post(
            "/api/v1/captures",
            json={
                "task_id": task_id,
                "structure_instance_id": "psi_xxx",
                "part_code": "other",
                "quick_part_tag": "crest",
                "quick_status": "undecided",
                "raw_note": "",
                "speech_text": "",
            },
        )
        assert bad.status_code == 422

        project_id = client.get("/api/v1/tasks").json()["data"]["items"][0]["project_id"]
        batch = client.post(
            f"/api/v1/projects/{project_id}/structure-instances/batch-init",
            json={"presets": [{"object_type": "main_dam", "count": 1}]},
        )
        assert batch.status_code == 200
        instance_id = batch.json()["data"]["items"][0]["instance_id"]

        ok = client.post(
            "/api/v1/captures",
            json={
                "task_id": task_id,
                "structure_instance_id": instance_id,
                "part_code": "dam_crest",
                "quick_part_tag": "crest",
                "quick_status": "undecided",
                "speech_text": "crest has minor crack",
            },
        )
        assert ok.status_code == 200
        assert ok.json()["data"]["capture_id"].startswith("cap_")


def test_capture_media_list_detail_and_confirm_to_result() -> None:
    with tempfile.TemporaryDirectory() as td:
        app = create_app("sqlite+pysqlite:///:memory:", storage_root=td)
        client = TestClient(app)
        task_id = _create_task(client, dam_type="earthfill")

        project_id = client.get("/api/v1/tasks").json()["data"]["items"][0]["project_id"]
        batch = client.post(
            f"/api/v1/projects/{project_id}/structure-instances/batch-init",
            json={"presets": [{"object_type": "main_dam", "count": 1}]},
        )
        assert batch.status_code == 200
        instance_id = batch.json()["data"]["items"][0]["instance_id"]

        created = client.post(
            "/api/v1/captures",
            json={
                "task_id": task_id,
                "structure_instance_id": instance_id,
                "part_code": "dam_crest",
                "quick_part_tag": "crest",
                "quick_status": "abnormal",
                "speech_text": "crest road crack visible",
                "created_by": "tester",
            },
        )
        assert created.status_code == 200
        capture_id = created.json()["data"]["capture_id"]

        up_photo = client.post(
            f"/api/v1/captures/{capture_id}/media",
            data={"media_type": "photo"},
            files={"file": ("cap.jpg", b"cap-photo", "image/jpeg")},
        )
        assert up_photo.status_code == 200
        assert up_photo.json()["data"]["media_type"] == "photo"

        up_audio = client.post(
            f"/api/v1/captures/{capture_id}/media",
            data={"media_type": "audio"},
            files={"file": ("note.m4a", b"cap-audio", "audio/mp4")},
        )
        assert up_audio.status_code == 200
        assert up_audio.json()["data"]["media_type"] == "audio"

        listed = client.get(f"/api/v1/tasks/{task_id}/captures", params={"review_status": "pending"})
        assert listed.status_code == 200
        items = listed.json()["data"]["items"]
        assert len(items) == 1
        assert items[0]["capture_id"] == capture_id
        assert items[0]["photo_count"] == 1

        detail = client.get(f"/api/v1/captures/{capture_id}")
        assert detail.status_code == 200
        media_types = [m["media_type"] for m in detail.json()["data"]["media"]]
        assert media_types == ["photo", "audio"]

        confirm = client.post(
            f"/api/v1/captures/{capture_id}/confirm",
            json={
                "item_code": "A2_CREST_ROAD",
                "check_status": "abnormal",
                "issue_flag": True,
                "issue_type": ["crack"],
                "severity_level": "moderate",
                "check_record": "manual confirmed",
                "suggestion": "repair soon",
                "checked_by": "reviewer",
            },
        )
        assert confirm.status_code == 200
        result_id = confirm.json()["data"]["result_id"]
        assert result_id.startswith("result_")

        detail_after = client.get(f"/api/v1/captures/{capture_id}")
        assert detail_after.status_code == 200
        row = detail_after.json()["data"]
        assert row["review_status"] == "confirmed"
        assert row["linked_result_id"] == result_id

        result_list = client.get(f"/api/v1/tasks/{task_id}/results")
        assert result_list.status_code == 200
        result_items = result_list.json()["data"]["items"]
        assert len(result_items) == 1
        assert result_items[0]["item_code"] == "A2_CREST_ROAD"
