create database app_db ;
use app_db;
-- Bài 1
create table users (
    user_id int auto_increment primary key,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    created_at datetime default current_timestamp
);
create table user_log (
    log_id int auto_increment primary key,
    user_id int,
    action varchar(255),
    log_time datetime default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);
delimiter $$
create trigger trg_log_new_user
after insert on users
for each row
begin
    insert into user_log(user_id, action)
    values (new.user_id, concat('người dùng ', new.username, ' đã đăng ký thành công'));
end $$
delimiter ;

delimiter $$
create procedure sp_register_user(
    in p_username varchar(50),
    in p_password varchar(255),
    in p_email varchar(100)
)
begin
    if exists (select 1 from users where username = p_username) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: tên đăng nhập đã tồn tại!';
    end if;

    if exists (select 1 from users where email = p_email) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: email này đã được sử dụng!';
    end if;

    insert into users(username, password, email)
    values (p_username, p_password, p_email);
end $$
delimiter ;

call sp_register_user('nguyenvana', 'pass123', 'a@example.com');
call sp_register_user('lethib', 'pass456', 'b@example.com');
call sp_register_user('tranc', 'pass789', 'c@example.com');
select * from users;
select * from user_log;

call sp_register_user('nguyenvana', 'newpass', 'new_email@example.com');
call sp_register_user('user_moi', 'newpass', 'b@example.com');

-- Bài 2
create table posts (
    post_id int auto_increment primary key,
    user_id int not null,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);
delimiter $$
create trigger trg_log_new_post
after insert on posts
for each row
begin
    insert into user_log(user_id, action)
    values (new.user_id, concat('đã đăng bài viết mới (id: ', new.post_id, ')'));
end $$
delimiter ;
delimiter $$
create procedure sp_create_post(
    in p_user_id int,
    in p_content text
)
begin
    if trim(p_content) = '' or p_content is null then
        signal sqlstate '45000' 
        set message_text = 'lỗi: nội dung bài viết không được để trống!';
    end if;
    if not exists (select 1 from users where user_id = p_user_id) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: người dùng không tồn tại!';
    end if;
    insert into posts(user_id, content)
    values (p_user_id, p_content);
end $$
delimiter ;
call sp_create_post(1, 'hôm nay trời đẹp quá!');
call sp_create_post(1, 'học sql thật thú vị.');
call sp_create_post(2, 'chào mọi người, mình là thành viên mới.');
call sp_create_post(2, 'có ai biết cách dùng trigger không?');
call sp_create_post(3, 'đang test tính năng đăng bài.');

select * from posts;
select * from user_log order by log_id desc;

call sp_create_post(1, '');
call sp_create_post(1, '   ');
call sp_create_post(999, 'nội dung này sẽ không được lưu.');

-- Bài 3
alter table posts 
add column like_count int default 0;
create table likes (
    user_id int,
    post_id int,
    created_at datetime default current_timestamp,
    primary key (user_id, post_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (post_id) references posts(post_id) on delete cascade
);
delimiter $$
create trigger trg_after_like
after insert on likes
for each row
begin
    update posts 
    set like_count = like_count + 1 
    where post_id = new.post_id;

    insert into user_log(user_id, action)
    values (new.user_id, concat('đã thích bài viết số ', new.post_id));
end $$
create trigger trg_after_unlike
after delete on likes
for each row
begin
    update posts 
    set like_count = like_count - 1 
    where post_id = old.post_id;

    insert into user_log(user_id, action)
    values (old.user_id, concat('đã bỏ thích bài viết số ', old.post_id));
end $$
delimiter ;

delimiter $$
create procedure sp_like_post(
    in p_user_id int,
    in p_post_id int
)
begin
    if not exists (select 1 from posts where post_id = p_post_id) then
        signal sqlstate '45000' set message_text = 'lỗi: bài viết không tồn tại!';
    end if;
    insert into likes(user_id, post_id) values (p_user_id, p_post_id);
end $$
create procedure sp_unlike_post(
    in p_user_id int,
    in p_post_id int
)
begin
    delete from likes 
    where user_id = p_user_id and post_id = p_post_id;
end $$
delimiter ;
call sp_like_post(1, 1);
call sp_like_post(2, 1);
call sp_like_post(3, 1);
select * from posts where post_id = 1;
select * from user_log order by log_id desc limit 5;

call sp_unlike_post(1, 1);
select * from posts where post_id = 1;
select * from user_log order by log_id desc limit 1;

call sp_like_post(2, 1);

-- bài 4
create table friends (
    user_id int,
    friend_id int,
    status varchar(20) default 'pending' check (status in ('pending', 'accepted')),
    created_at datetime default current_timestamp,
    primary key (user_id, friend_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (friend_id) references users(user_id) on delete cascade
);
delimiter $$
create trigger trg_log_friend_request
after insert on friends
for each row
begin
    insert into user_log(user_id, action)
    values (new.user_id, concat('đã gửi lời mời kết bạn tới user id: ', new.friend_id));
end $$
delimiter ;
delimiter $$
create procedure sp_send_friend_request(
    in p_sender_id int,
    in p_receiver_id int
)
begin
    if p_sender_id = p_receiver_id then
        signal sqlstate '45000' 
        set message_text = 'lỗi: không thể tự gửi lời mời kết bạn cho chính mình!';
    end if;
    if not exists (select 1 from users where user_id = p_receiver_id) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: người dùng nhận không tồn tại!';
    end if;
    if exists (select 1 from friends where user_id = p_sender_id and friend_id = p_receiver_id) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: bạn đã gửi lời mời cho người này rồi!';
    end if;
    if exists (select 1 from friends where user_id = p_receiver_id and friend_id = p_sender_id) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: người này đã gửi lời mời cho bạn, hãy chấp nhận thay vì gửi mới!';
    end if;
    insert into friends(user_id, friend_id)
    values (p_sender_id, p_receiver_id);
end $$
delimiter ;

call sp_send_friend_request(1, 2);
call sp_send_friend_request(1, 3);
select * from friends; 
select * from user_log order by log_id desc limit 2;

call sp_send_friend_request(1, 1);
call sp_send_friend_request(1, 2);
call sp_send_friend_request(2, 1);

-- bài 5
delimiter $$
create trigger trg_after_accept_friend
after update on friends
for each row
begin
    if new.status = 'accepted' and old.status = 'pending' then
        insert into user_log(user_id, action)
        values (new.friend_id, concat('đã chấp nhận lời mời từ user id: ', new.user_id));
    end if;
end $$
delimiter ;

delimiter $$
create procedure sp_accept_friend_request(
    in p_sender_id int,  
    in p_receiver_id int  
)
begin
    if not exists (
        select 1 from friends 
        where user_id = p_sender_id 
          and friend_id = p_receiver_id 
          and status = 'pending'
    ) then
        signal sqlstate '45000' 
        set message_text = 'lỗi: không tìm thấy lời mời kết bạn chờ duyệt!';
    end if;
    start transaction;
        update friends 
        set status = 'accepted'
        where user_id = p_sender_id and friend_id = p_receiver_id;
        insert into friends (user_id, friend_id, status)
        values (p_receiver_id, p_sender_id, 'accepted')
        on duplicate key update status = 'accepted';

    commit;
end $$
delimiter ;
select * from friends;
call sp_accept_friend_request(1, 2);
select * from user_log order by log_id desc limit 1;

-- Bài 6
delimiter $$
create trigger trg_log_unfriend
after delete on friends
for each row
begin
    insert into user_log(user_id, action)
    values (old.user_id, concat('đã hủy kết bạn với user id: ', old.friend_id));
end $$
delimiter ;

delimiter $$
create procedure sp_unfriend(
    in p_user_a int,
    in p_user_b int,
    in p_test_fail boolean -- TRUE: Chạy thử lỗi (Rollback), FALSE: Chạy thật (Commit)
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'ĐÃ ROLLBACK! Kết quả bị hủy, dữ liệu được bảo toàn.' as ket_qua_test;
    end;

    start transaction;
        if not exists (select 1 from friends where user_id = p_user_a and friend_id = p_user_b and status = 'accepted') then
            signal sqlstate '45000' set message_text = 'Lỗi: Hai người này chưa phải là bạn bè!';
        end if;
        delete from friends where user_id = p_user_a and friend_id = p_user_b;
        if p_test_fail = true then
            signal sqlstate '45000' set message_text = 'Lỗi giả định để kiểm tra tính năng Rollback!';
        end if;
        delete from friends where user_id = p_user_b and friend_id = p_user_a;
        
    commit;
    select 'THÀNH CÔNG! Đã hủy kết bạn 2 chiều.' as ket_qua;
end $$
delimiter ;

call sp_unfriend(1, 2, true);
select * from friends where user_id in (1, 2) and friend_id in (1, 2);
call sp_unfriend(1, 2, false);
select * from friends where user_id in (1, 2) and friend_id in (1, 2);

-- bài 7
create table comments (
    comment_id int auto_increment primary key,
    user_id int,
    post_id int,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (post_id) references posts(post_id) on delete cascade
);

delimiter $$
create trigger trg_log_delete_post
after delete on posts
for each row
begin
    insert into user_log(user_id, action)
    values (old.user_id, concat('đã xóa bài viết mã số: ', old.post_id));
end $$
delimiter ;


delimiter $$
create procedure sp_delete_post(
    in p_post_id int,
    in p_user_id int,   
    in p_test_fail boolean -- TRUE: Test Rollback, FALSE: Chạy thật
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'ĐÃ ROLLBACK! Dữ liệu bài viết được khôi phục.' as ket_qua_test;
    end;

    start transaction;
        if not exists (select 1 from posts where post_id = p_post_id) then
            signal sqlstate '45000' set message_text = 'Lỗi: Bài viết không tồn tại!';
        end if;
        if not exists (select 1 from posts where post_id = p_post_id and user_id = p_user_id) then
            signal sqlstate '45000' set message_text = 'Lỗi: Bạn không có quyền xóa bài viết này!';
        end if;
        delete from posts where post_id = p_post_id;
        if p_test_fail = true then
            signal sqlstate '45000' set message_text = 'Lỗi giả định để kiểm tra tính năng Rollback!';
        end if;
        -- =========================
        
    commit;
    select 'THÀNH CÔNG! Đã xóa bài viết và dữ liệu liên quan.' as ket_qua;
end $$
delimiter ;

insert into posts(user_id, content) values (1, 'Bài viết demo sắp bị xóa');
set @id_bai_viet = last_insert_id(); 

insert into likes(user_id, post_id) values (2, @id_bai_viet);
insert into comments(user_id, post_id, content) values (2, @id_bai_viet, 'Đừng xóa bài này nhé!');

select * from posts where post_id = @id_bai_viet;
select * from likes where post_id = @id_bai_viet;
select * from comments where post_id = @id_bai_viet;

call sp_delete_post(@id_bai_viet, 1, true);
select * from posts where post_id = @id_bai_viet;

call sp_delete_post(@id_bai_viet, 2, false);
call sp_delete_post(@id_bai_viet, 1, false);
select * from posts where post_id = @id_bai_viet;  
select * from likes where post_id = @id_bai_viet;    
select * from comments where post_id = @id_bai_viet; 

-- Xem log
select * from user_log order by log_id desc limit 1;

-- bài 8
drop trigger if exists trg_before_delete_user;
delimiter $$
create trigger trg_before_delete_user
before delete on users
for each row
begin
    declare continue handler for sqlexception begin end; 
end $$
delimiter ;

delimiter $$
create procedure sp_delete_user(
    in p_user_id int,
    in p_test_fail boolean -- TRUE: Test Rollback, FALSE: Chạy thật
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'ĐÃ ROLLBACK! Tài khoản và dữ liệu được bảo toàn.' as ket_qua_test;
    end;

    start transaction;
        if not exists (select 1 from users where user_id = p_user_id) then
            signal sqlstate '45000' set message_text = 'Lỗi: Người dùng không tồn tại!';
        end if;
        delete from friends where user_id = p_user_id or friend_id = p_user_id;
        delete from likes where user_id = p_user_id;
        delete from comments where user_id = p_user_id;
        delete from posts where user_id = p_user_id;
        delete from user_log where user_id = p_user_id;
        delete from users where user_id = p_user_id;
        if p_test_fail = true then
            signal sqlstate '45000' set message_text = 'Lỗi giả định để kiểm tra Rollback toàn bộ dữ liệu!';
        end if;

    commit;
    select 'THÀNH CÔNG! Đã xóa vĩnh viễn tài khoản và mọi dữ liệu liên quan.' as ket_qua;
end $$
delimiter ;

insert into users(username, password, email) values ('user_to_delete', 'pass123', 'delete@me.com');
set @uid = last_insert_id();
insert into users(username, password, email) values ('friend_user', 'pass123', 'friend@me.com');
set @fid = last_insert_id();


insert into friends(user_id, friend_id, status) values (@uid, @fid, 'accepted'); 
insert into posts(user_id, content) values (@uid, 'Bài viết của người sắp bị xóa'); 
insert into likes(user_id, post_id) values (@uid, 1); 
insert into comments(user_id, post_id, content) values (@uid, 1, 'Comment sắp bay màu'); 

select * from users where user_id = @uid;
select * from friends where user_id = @uid or friend_id = @uid;
select * from posts where user_id = @uid;
select * from comments where user_id = @uid;

call sp_delete_user(@uid, true);
select * from users where user_id = @uid;
call sp_delete_user(@uid, false);

select * from users where user_id = @uid;
select * from friends where user_id = @uid or friend_id = @uid;
select * from posts where user_id = @uid;
select * from user_log where user_id = @uid;