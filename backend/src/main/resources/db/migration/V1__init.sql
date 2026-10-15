-- =====================================================================
-- 한결 초기 스키마 (MySQL 8.4)
-- 원본: hangyul/exec/03_schema.sql (PostgreSQL) 을 MySQL 문법으로 이식
-- 규칙
--   * PK 는 모든 테이블 id BIGINT AUTO_INCREMENT
--   * 시각은 DATETIME(6), 항상 UTC 로 저장 (앱: hibernate.jdbc.time_zone=UTC)
--   * Java enum 으로 매핑할 문자열 컬럼은 대문자 값 + CHECK 제약
--   * 문자셋은 MySQL 8.4 기본값 utf8mb4 사용 (한글·이모지 저장 가능)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 계정
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id                BIGINT       NOT NULL AUTO_INCREMENT,
    email             VARCHAR(100),
    password          VARCHAR(255),
    name              VARCHAR(50)  NOT NULL,
    nickname          VARCHAR(50),
    phone             VARCHAR(20),
    birth_date        DATE,
    profile_image_url VARCHAR(500),
    provider          VARCHAR(20)  NOT NULL,
    provider_id       VARCHAR(100),
    user_type         VARCHAR(20)  NOT NULL,
    email_verified    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at        DATETIME(6)  NOT NULL,
    updated_at        DATETIME(6)  NOT NULL,
    deleted_at        DATETIME(6),
    PRIMARY KEY (id),
    CONSTRAINT uk_users_email UNIQUE (email),
    CONSTRAINT uk_users_provider_provider_id UNIQUE (provider, provider_id),
    CONSTRAINT ck_users_provider CHECK (provider IN ('LOCAL', 'KAKAO')),
    CONSTRAINT ck_users_user_type CHECK (user_type IN ('FACILITY', 'GUARDIAN'))
);

-- ---------------------------------------------------------------------
-- 기준 정보: 시설 / 보호자 / 어르신
-- ---------------------------------------------------------------------
CREATE TABLE facility (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    user_id             BIGINT       NOT NULL,
    name                VARCHAR(100) NOT NULL,
    contact_phone       VARCHAR(20),
    contact_email       VARCHAR(100),
    contract_started_at DATETIME(6)  NOT NULL,
    contract_ended_at   DATETIME(6),
    send_time           TIME,
    created_at          DATETIME(6)  NOT NULL,
    updated_at          DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_facility_user_id UNIQUE (user_id),
    CONSTRAINT fk_facility_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE guardian (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    user_id    BIGINT,
    name       VARCHAR(50) NOT NULL,
    birth_date DATE,
    phone      VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_guardian_user_id UNIQUE (user_id),
    INDEX idx_guardian_phone (phone),
    INDEX idx_guardian_name_birth_date (name, birth_date),
    CONSTRAINT fk_guardian_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE resident (
    id            BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id   BIGINT      NOT NULL,
    name          VARCHAR(50) NOT NULL,
    birth_date    DATE,
    room          VARCHAR(20),
    admitted_at   DATE        NOT NULL,
    discharged_at DATE,
    created_at    DATETIME(6) NOT NULL,
    updated_at    DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_resident_facility_admitted (facility_id, admitted_at),
    INDEX idx_resident_facility_name (facility_id, name),
    CONSTRAINT fk_resident_facility FOREIGN KEY (facility_id) REFERENCES facility (id)
);

CREATE TABLE facility_guardian (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id BIGINT      NOT NULL,
    guardian_id BIGINT      NOT NULL,
    created_at  DATETIME(6) NOT NULL,
    updated_at  DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_facility_guardian UNIQUE (facility_id, guardian_id),
    INDEX idx_facility_guardian_guardian (guardian_id),
    CONSTRAINT fk_facility_guardian_facility FOREIGN KEY (facility_id) REFERENCES facility (id),
    CONSTRAINT fk_facility_guardian_guardian FOREIGN KEY (guardian_id) REFERENCES guardian (id)
);

CREATE TABLE resident_guardian (
    id               BIGINT      NOT NULL AUTO_INCREMENT,
    resident_id      BIGINT      NOT NULL,
    guardian_id      BIGINT      NOT NULL,
    relationship     VARCHAR(30),
    consent_status   VARCHAR(20) NOT NULL,
    consent_given_at DATETIME(6),
    interest_tag     VARCHAR(20),
    created_at       DATETIME(6) NOT NULL,
    updated_at       DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_resident_guardian UNIQUE (resident_id, guardian_id),
    INDEX idx_resident_guardian_guardian_consent (guardian_id, consent_status),
    CONSTRAINT ck_resident_guardian_consent_status
        CHECK (consent_status IN ('CONSENTED', 'REVOKED', 'PENDING', 'MATCHING_FAILED')),
    CONSTRAINT ck_resident_guardian_interest_tag
        CHECK (interest_tag IS NULL OR interest_tag IN ('HIGH', 'NORMAL', 'LOW')),
    CONSTRAINT fk_resident_guardian_resident FOREIGN KEY (resident_id) REFERENCES resident (id),
    CONSTRAINT fk_resident_guardian_guardian FOREIGN KEY (guardian_id) REFERENCES guardian (id)
);

-- ---------------------------------------------------------------------
-- 업로드 / 돌봄기록
-- ---------------------------------------------------------------------
CREATE TABLE upload_history (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    facility_id    BIGINT       NOT NULL,
    kind           VARCHAR(30)  NOT NULL,
    file_name      VARCHAR(255),
    status         VARCHAR(20)  NOT NULL,
    target_period  VARCHAR(50),
    resident_count INT,
    error_message  VARCHAR(500),
    uploaded_at    DATETIME(6)  NOT NULL,
    completed_at   DATETIME(6),
    PRIMARY KEY (id),
    INDEX idx_upload_history_facility_kind_uploaded (facility_id, kind, uploaded_at),
    CONSTRAINT ck_upload_history_kind
        CHECK (kind IN ('RESIDENT_BASE', 'GUARDIAN_BASE', 'CARE_RECORD', 'PROGRAM', 'MONTHLY_PROGRAM')),
    CONSTRAINT ck_upload_history_status
        CHECK (status IN ('PENDING', 'PARSING', 'DONE', 'FAILED')),
    CONSTRAINT fk_upload_history_facility FOREIGN KEY (facility_id) REFERENCES facility (id)
);

CREATE TABLE raw_record (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id       BIGINT      NOT NULL,
    upload_id         BIGINT      NOT NULL,
    resident_id       BIGINT,
    raw_resident_name VARCHAR(50),
    record_date       DATE        NOT NULL,
    raw_data          JSON        NOT NULL,
    match_status      VARCHAR(20) NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_raw_record_resident_date (resident_id, record_date),
    INDEX idx_raw_record_facility_date (facility_id, record_date),
    CONSTRAINT ck_raw_record_match_status
        CHECK (match_status IN ('AUTO_MATCHED', 'MANUAL_RESOLVED', 'FAILED')),
    CONSTRAINT fk_raw_record_facility FOREIGN KEY (facility_id) REFERENCES facility (id),
    CONSTRAINT fk_raw_record_upload FOREIGN KEY (upload_id) REFERENCES upload_history (id),
    CONSTRAINT fk_raw_record_resident FOREIGN KEY (resident_id) REFERENCES resident (id)
);

-- generated_text : 정제기가 처음 만든 문장 (기존 llm_text)
-- current_text   : 직원이 편집한 최종 문장
CREATE TABLE refined_record (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id     BIGINT      NOT NULL,
    raw_record_id   BIGINT      NOT NULL,
    resident_id     BIGINT      NOT NULL,
    record_date     DATE        NOT NULL,
    generated_text  JSON        NOT NULL,
    current_text    JSON        NOT NULL,
    approval_status VARCHAR(20) NOT NULL,
    created_at      DATETIME(6) NOT NULL,
    updated_at      DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_refined_record_raw_record UNIQUE (raw_record_id),
    CONSTRAINT uk_refined_record_resident_date UNIQUE (resident_id, record_date),
    INDEX idx_refined_record_resident_status_date (resident_id, approval_status, record_date),
    INDEX idx_refined_record_facility_status_updated (facility_id, approval_status, updated_at),
    CONSTRAINT ck_refined_record_approval_status
        CHECK (approval_status IN ('DRAFT', 'APPROVED', 'REJECTED')),
    CONSTRAINT fk_refined_record_facility FOREIGN KEY (facility_id) REFERENCES facility (id),
    CONSTRAINT fk_refined_record_raw_record FOREIGN KEY (raw_record_id) REFERENCES raw_record (id),
    CONSTRAINT fk_refined_record_resident FOREIGN KEY (resident_id) REFERENCES resident (id)
);

-- ---------------------------------------------------------------------
-- 프로그램 / 사진
-- ---------------------------------------------------------------------
CREATE TABLE monthly_program (
    id               BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id      BIGINT      NOT NULL,
    month_start_date DATE        NOT NULL,
    raw_data         JSON        NOT NULL,
    created_at       DATETIME(6) NOT NULL,
    updated_at       DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_monthly_program_facility_month UNIQUE (facility_id, month_start_date),
    CONSTRAINT fk_monthly_program_facility FOREIGN KEY (facility_id) REFERENCES facility (id)
);

CREATE TABLE program (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id BIGINT      NOT NULL,
    upload_id   BIGINT,
    target_date DATE        NOT NULL,
    raw_data    JSON,
    created_at  DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_program_facility_date (facility_id, target_date),
    CONSTRAINT fk_program_facility FOREIGN KEY (facility_id) REFERENCES facility (id),
    CONSTRAINT fk_program_upload FOREIGN KEY (upload_id) REFERENCES upload_history (id)
);

CREATE TABLE program_participant (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    program_id        BIGINT      NOT NULL,
    resident_id       BIGINT,
    raw_resident_name VARCHAR(50) NOT NULL,
    attended          BOOLEAN     NOT NULL,
    match_status      VARCHAR(20) NOT NULL,
    raw_data          JSON,
    created_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_program_participant_resident_attended (resident_id, attended),
    CONSTRAINT ck_program_participant_match_status
        CHECK (match_status IN ('AUTO_MATCHED', 'MANUAL_RESOLVED', 'FAILED')),
    CONSTRAINT fk_program_participant_program FOREIGN KEY (program_id) REFERENCES program (id),
    CONSTRAINT fk_program_participant_resident FOREIGN KEY (resident_id) REFERENCES resident (id)
);

-- object_key : 스토리지(S3 등) 안의 파일 경로. 조회할 때마다 URL 을 새로 발급한다 (기존 photo_url)
CREATE TABLE program_photo (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    program_id  BIGINT       NOT NULL,
    object_key  VARCHAR(500) NOT NULL,
    uploaded_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_program_photo_program FOREIGN KEY (program_id) REFERENCES program (id)
);

CREATE TABLE personal_photo (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    program_id  BIGINT       NOT NULL,
    resident_id BIGINT       NOT NULL,
    object_key  VARCHAR(500) NOT NULL,
    uploaded_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_personal_photo_program FOREIGN KEY (program_id) REFERENCES program (id),
    CONSTRAINT fk_personal_photo_resident FOREIGN KEY (resident_id) REFERENCES resident (id)
);

-- ---------------------------------------------------------------------
-- 알림 발송
-- provider_* : 발송 업체(Solapi) 쪽 식별자. 업체가 바뀌어도 컬럼명은 그대로 쓰도록 중립적으로 명명
-- ---------------------------------------------------------------------
CREATE TABLE notification (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    facility_id         BIGINT       NOT NULL,
    guardian_id         BIGINT       NOT NULL,
    refined_record_id   BIGINT       NOT NULL,
    upload_id           BIGINT,
    template_code       VARCHAR(20)  NOT NULL,
    target_date         DATE,
    status              VARCHAR(20)  NOT NULL,
    fail_reason         VARCHAR(255),
    sent_text_snapshot  TEXT,
    scheduled_at        DATETIME(6),
    sent_at             DATETIME(6),
    provider_group_id   VARCHAR(64),
    provider_message_id VARCHAR(64),
    created_at          DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_notification_facility_upload_created (facility_id, upload_id, created_at),
    INDEX idx_notification_upload_status (upload_id, status),
    INDEX idx_notification_guardian_sent (guardian_id, sent_at),
    CONSTRAINT ck_notification_status
        CHECK (status IN ('QUEUED', 'SCHEDULED', 'SENT', 'FAILED')),
    CONSTRAINT fk_notification_facility FOREIGN KEY (facility_id) REFERENCES facility (id),
    CONSTRAINT fk_notification_guardian FOREIGN KEY (guardian_id) REFERENCES guardian (id),
    CONSTRAINT fk_notification_refined_record FOREIGN KEY (refined_record_id) REFERENCES refined_record (id),
    CONSTRAINT fk_notification_upload FOREIGN KEY (upload_id) REFERENCES upload_history (id)
);

-- ---------------------------------------------------------------------
-- 감사 로그
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    id           BIGINT      NOT NULL AUTO_INCREMENT,
    facility_id  BIGINT,
    actor_type   VARCHAR(20) NOT NULL,
    actor_id     BIGINT,
    action       VARCHAR(50) NOT NULL,
    target_type  VARCHAR(30),
    target_id    BIGINT,
    before_value JSON,
    after_value  JSON,
    created_at   DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_audit_log_target (target_type, target_id),
    CONSTRAINT ck_audit_log_actor_type CHECK (actor_type IN ('FACILITY', 'GUARDIAN', 'SYSTEM')),
    CONSTRAINT fk_audit_log_facility FOREIGN KEY (facility_id) REFERENCES facility (id)
);
