DROP DATABASE IF EXISTS StudentManagement;
CREATE DATABASE StudentManagement;
USE StudentManagement;

-- =============================================
-- 1. TABLE STRUCTURE
-- =============================================

-- Table: Students
CREATE TABLE Students (
    StudentID CHAR(5) PRIMARY KEY,
    FullName VARCHAR(50) NOT NULL,
    TotalDebt DECIMAL(10,2) DEFAULT 0
);

-- Table: Subjects
CREATE TABLE Subjects (
    SubjectID CHAR(5) PRIMARY KEY,
    SubjectName VARCHAR(50) NOT NULL,
    Credits INT CHECK (Credits > 0)
);

-- Table: Grades
CREATE TABLE Grades (
    StudentID CHAR(5),
    SubjectID CHAR(5),
    Score DECIMAL(4,2) CHECK (Score BETWEEN 0 AND 10),
    PRIMARY KEY (StudentID, SubjectID),
    CONSTRAINT FK_Grades_Students FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    CONSTRAINT FK_Grades_Subjects FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID)
);

-- Table: GradeLog
CREATE TABLE GradeLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    StudentID CHAR(5),
    OldScore DECIMAL(4,2),
    NewScore DECIMAL(4,2),
    ChangeDate DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. SEED DATA
-- =============================================

-- Insert Students
INSERT INTO Students (StudentID, FullName, TotalDebt) VALUES 
('SV01', 'Ho Khanh Linh', 5000000),
('SV03', 'Tran Thi Khanh Huyen', 0);

-- Insert Subjects
INSERT INTO Subjects (SubjectID, SubjectName, Credits) VALUES 
('SB01', 'Co so du lieu', 3),
('SB02', 'Lap trinh Java', 4),
('SB03', 'Lap trinh C', 3);

-- Insert Grades
INSERT INTO Grades (StudentID, SubjectID, Score) VALUES 
('SV01', 'SB01', 8.5), -- Passed
('SV03', 'SB02', 3.0); -- Failed

-- bài 1
delimiter $$
create trigger tg_CheckScore
before insert on Grades
for each row
begin
    if new.Score < 0 then
        set new.Score = 0;
    elseif new.Score > 10 then
        set new.Score = 10;
    end if;
end $$
delimiter ;


-- bài 2
start transaction;
insert into Students (StudentID, FullName) 
values ('SV02', 'Ha Bich Ngoc');
update Students 
set TotalDebt = 5000000 
where StudentID = 'SV02';
commit;
-- bài 3
delimiter $$
create trigger tg_LogGradeUpdate
after update on Grades
for each row
begin
    if old.Score <> new.Score then
        insert into GradeLog (StudentID, OldScore, NewScore, ChangeDate)
        values (old.StudentID, old.Score, new.Score, now());
    end if;
end $$
delimiter ;

update grades set Score = 7 where grades.studentID = "SV03";
select * from gradelog;

-- bài 4
delimiter $$
create procedure sp_PayTuition()
begin
    declare current_debt decimal(10,2);
    start transaction;
    update Students 
    set TotalDebt = TotalDebt - 2000000 
    where StudentID = 'SV01';

    select TotalDebt into current_debt 
    from Students 
    where StudentID = 'SV01';

    if current_debt < 0 then
        rollback;
        select 'thất bại: đóng thừa tiền, đã hoàn tác' as Message;
    else
        commit;
        select 'thành công: đã cập nhật học phí' as Message;
    end if;
end $$
delimiter ;
call sp_PayTuition();

-- bài 5
delimiter $$
create trigger tg_PreventPassUpdate
before update on Grades
for each row
begin
    if old.Score >= 4.0 then
        signal sqlstate '45000'
        set message_text = 'lỗi: sinh viên đã qua môn, không được phép sửa điểm';
    end if;
end $$
delimiter ;

update grades set Score = 7 where grades.studentID = "SV03";
select * from gradelog;

-- bài 6
delimiter $$
create procedure sp_DeleteStudentGrade(
    in p_StudentID char(5),
    in p_SubjectID char(5)
)
begin
    declare v_old_score decimal(4,2);
    start transaction;
    select Score into v_old_score
    from Grades
    where StudentID = p_StudentID and SubjectID = p_SubjectID;
    insert into GradeLog (StudentID, OldScore, NewScore, ChangeDate)
    values (p_StudentID, v_old_score, null, now());
    delete from Grades
    where StudentID = p_StudentID and SubjectID = p_SubjectID;
    if row_count() = 0 then
        rollback;
        select 'thất bại: không tìm thấy dữ liệu để xóa' as Message;
    else
        commit;
        select 'thành công: đã xóa điểm và lưu vết' as Message;
    end if;
end $$
delimiter ;

call sp_DeleteStudentGrade('SV01', 'SB01');
select * from Grades where StudentID = 'SV01';
select * from GradeLog order by LogID desc limit 1;

call sp_DeleteStudentGrade('SV99', 'SB99');
select * from GradeLog order by LogID desc limit 5;
