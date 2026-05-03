# tests/integration/feature/document_collection/plaza_round_trip_test.gd
#
# PlazaRoundTripTest — full Epic DoD round-trip integration test.
#
# COVERAGE: AC-DC-12.2 (Epic DoD: place → collect → save → reload → verify)
#           AC-DC-5.3 (save-during-reach restores body as uncollected)

class_name PlazaRoundTripTest
extends GdUnitTestSuite

const _PLAZA_SCENE: String = "res://scenes/sections/plaza.tscn"
const _SAVE_PATH: String = "user://test_dc_round_trip.res"
const _LOGBOOK_ID: StringName = &"plaza_security_logbook_001"
const _TOURIST_ID: StringName = &"plaza_tourist_register_001"
const _MAINTENANCE_ID: StringName = &"plaza_maintenance_clipboard_001"


func after_test() -> void:
    # Cleanup save file from this test
    if FileAccess.file_exists(_SAVE_PATH):
        DirAccess.remove_absolute(_SAVE_PATH)


func _load_plaza() -> Node3D:
    var scene: PackedScene = load(_PLAZA_SCENE)
    var plaza: Node3D = scene.instantiate() as Node3D
    add_child(plaza)
    auto_free(plaza)
    return plaza


func _find_body_by_id(plaza: Node3D, doc_id: StringName) -> DocumentBody:
    for body in plaza.get_tree().get_nodes_in_group(&"section_documents"):
        if body is DocumentBody and body.document != null and body.document.id == doc_id:
            return body
    return null


# AC-5: Full round-trip — pickup, capture, save, reload, restore
func test_plaza_three_documents_full_round_trip() -> void:
    # Arrange — load Plaza scene
    var plaza: Node3D = _load_plaza()
    var dc: DocumentCollection = plaza.get_node("Systems/DocumentCollection") as DocumentCollection

    assert_object(dc).override_failure_message(
        "Plaza scene must have Systems/DocumentCollection node (DC-005 AC-3)."
    ).is_not_null()

    var section_bodies: Array = plaza.get_tree().get_nodes_in_group(&"section_documents")
    assert_int(section_bodies.size()).override_failure_message(
        "Plaza must have exactly 3 DocumentBody instances in section_documents group. Got %d." % section_bodies.size()
    ).is_equal(3)

    var logbook_body: DocumentBody = _find_body_by_id(plaza, _LOGBOOK_ID)
    assert_object(logbook_body).is_not_null()

    # Act — collect logbook (simulate player_interacted)
    Events.player_interacted.emit(logbook_body)
    await get_tree().process_frame  # wait for queue_free deferral

    # Assert — pickup happened
    assert_bool(dc._collected.has(_LOGBOOK_ID)).is_true()

    # Act — capture state
    var state: DocumentCollectionState = dc.capture()
    assert_bool(state.collected.has(_LOGBOOK_ID)).is_true()

    # Act — wrap in SaveGame and round-trip via ResourceSaver/Loader
    var save_game: SaveGame = SaveGame.new()
    save_game.documents = state
    var save_result: int = ResourceSaver.save(save_game, _SAVE_PATH)
    assert_int(save_result).override_failure_message(
        "ResourceSaver.save() must return OK (0). Got %d." % save_result
    ).is_equal(OK)

    var loaded: SaveGame = ResourceLoader.load(_SAVE_PATH) as SaveGame
    assert_object(loaded).is_not_null()
    assert_bool(loaded.documents.collected.has(_LOGBOOK_ID)).override_failure_message(
        "Loaded SaveGame.documents.collected must contain logbook id."
    ).is_true()

    # Act — restore on a fresh DC + section instance
    var fresh_plaza: Node3D = _load_plaza()
    var fresh_dc: DocumentCollection = fresh_plaza.get_node("Systems/DocumentCollection") as DocumentCollection
    fresh_dc.restore(loaded.documents)
    await get_tree().process_frame  # wait for spawn-gate queue_free

    # Assert — logbook absent (spawn-gate ran), other 2 still present
    var fresh_logbook: DocumentBody = _find_body_by_id(fresh_plaza, _LOGBOOK_ID)
    assert_object(fresh_logbook).override_failure_message(
        "After restore, logbook body must be absent (spawn-gate freed it)."
    ).is_null()

    var fresh_tourist: DocumentBody = _find_body_by_id(fresh_plaza, _TOURIST_ID)
    var fresh_maintenance: DocumentBody = _find_body_by_id(fresh_plaza, _MAINTENANCE_ID)
    assert_object(fresh_tourist).override_failure_message(
        "Tourist register body must still be present after restore."
    ).is_not_null()
    assert_object(fresh_maintenance).override_failure_message(
        "Maintenance clipboard body must still be present after restore."
    ).is_not_null()


# AC-6: Save-during-reach — capture before pickup, restore preserves bodies
func test_save_during_reach_restores_body_as_uncollected() -> void:
    var plaza: Node3D = _load_plaza()
    var dc: DocumentCollection = plaza.get_node("Systems/DocumentCollection") as DocumentCollection

    # Act — capture before any pickup
    var state: DocumentCollectionState = dc.capture()
    assert_int(state.collected.size()).override_failure_message(
        "Pre-pickup capture must yield empty collected array."
    ).is_equal(0)

    # Act — round-trip and restore on fresh section
    var save_game: SaveGame = SaveGame.new()
    save_game.documents = state
    ResourceSaver.save(save_game, _SAVE_PATH)
    var loaded: SaveGame = ResourceLoader.load(_SAVE_PATH) as SaveGame

    var fresh_plaza: Node3D = _load_plaza()
    var fresh_dc: DocumentCollection = fresh_plaza.get_node("Systems/DocumentCollection") as DocumentCollection
    fresh_dc.restore(loaded.documents)
    await get_tree().process_frame

    # Assert — all 3 bodies still present (none were collected pre-save)
    assert_object(_find_body_by_id(fresh_plaza, _LOGBOOK_ID)).is_not_null()
    assert_object(_find_body_by_id(fresh_plaza, _TOURIST_ID)).is_not_null()
    assert_object(_find_body_by_id(fresh_plaza, _MAINTENANCE_ID)).is_not_null()
