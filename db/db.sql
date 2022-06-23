CREATE EXTENSION IF NOT EXISTS citext;

CREATE UNLOGGED TABLE Users
(
    id       serial             NOT NULL,
    nickname citext COLLATE "C" NOT NULL UNIQUE PRIMARY KEY,
    fullname varchar(255)       NOT NULL,
    about    text               NOT NULL,
    email    citext             NOT NULL UNIQUE
);

CREATE UNLOGGED TABLE Forum
(
    id            serial             NOT NULL,
    title         varchar(255)       NOT NULL,
    user_nickname citext COLLATE "C" NOT NULL REFERENCES Users (nickname) ON DELETE CASCADE,
    slug          citext             NOT NULL UNIQUE PRIMARY KEY,
    posts         int                NOT NULL default 0,
    threads       int                NOT NULL default 0
);

CREATE UNLOGGED TABLE ForumUsers
(
    nickname citext COLLATE "C" NOT NULL REFERENCES Users (nickname) ON DELETE CASCADE,
    fullname varchar(255)       NOT NULL,
    about    text               NOT NULL,
    email    citext             NOT NULL REFERENCES Users (email) ON DELETE CASCADE,
    forum    citext             NOT NULL REFERENCES Forum (slug) ON DELETE CASCADE,
    PRIMARY KEY (nickname, forum)
);

CREATE UNLOGGED TABLE Thread
(
    id            serial             NOT NULL PRIMARY KEY,
    title         varchar(255)       NOT NULL,
    user_nickname citext COLLATE "C" NOT NULL REFERENCES Users (nickname) ON DELETE CASCADE,
    forum         citext             NOT NULL REFERENCES Forum (slug) ON DELETE CASCADE,
    message       text               NOT NULL,
    votes         int         default 0,
    slug          citext             NOT NULL,
    created       timestamptz DEFAULT now()
);

CREATE UNLOGGED TABLE Post
(
    id        serial             NOT NULL PRIMARY KEY,
    parent    int                NOT NULL default 0,
    author    citext COLLATE "C" NOT NULL REFERENCES Users (nickname) ON DELETE CASCADE,
    message   text               NOT NULL,
    is_edited boolean            NOT NULL,
    forum     citext             NOT NULL REFERENCES Forum (slug) ON DELETE CASCADE,
    thread    int                NOT NULL,
    created   timestamptz                 DEFAULT now(),
    pathTree  int[]                       default array []::int[]
);

CREATE UNLOGGED TABLE Vote
(
    threadId int                NOT NULL REFERENCES Thread (id) ON DELETE CASCADE,
    nickname citext COLLATE "C" NOT NULL REFERENCES Users (nickname) ON DELETE CASCADE,
    voice    int                NOT NULL default 0,
    PRIMARY KEY (threadId, nickname)
);

-- Users
CREATE INDEX IF NOT EXISTS  index_user_nickname_email ON Users (nickname, email);

-- Threads
CREATE INDEX IF NOT EXISTS index_forum_thread on Thread using hash (forum);
CREATE INDEX IF NOT EXISTS index_slug_thread on Thread using hash (slug);
CREATE INDEX IF NOT EXISTS index_thread_forum_created ON Thread (forum, created);

-- Post
CREATE INDEX IF NOT EXISTS index_author_post on Post using hash (author);
CREATE INDEX IF NOT EXISTS index_forum_post on Post using hash (forum);
CREATE INDEX IF NOT EXISTS index_parent_post on Post (parent);
CREATE INDEX IF NOT EXISTS index_thread_pathTree_post on post (thread, pathtree);
CREATE INDEX IF NOT EXISTS index_first_parent_post on post ((pathtree[1]), pathtree);

-- Vote
CREATE INDEX IF NOT EXISTS index_search_user_vote ON Vote (nickname, threadId, voice);


CREATE OR REPLACE FUNCTION insertPathTree() RETURNS trigger as
$insertPathTree$
Declare
    parent_path int[];
begin
    if (new.parent = 0) then
        new.pathtree := array_append(new.pathtree, new.id);
    else
        select pathtree from post where id = new.parent into parent_path;
        new.pathtree := new.pathtree || parent_path || new.id;
    end if;
    return new;
end
$insertPathTree$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insertThreadsVotes() RETURNS trigger as
$insertThreadsVotes$
begin
    update thread set votes = thread.votes + new.voice where id = new.threadid;
    return new;
end;
$insertThreadsVotes$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updateThreadsVotes() RETURNS trigger as
$updateThreadsVotes$
begin
    update thread set votes = thread.votes + new.voice - old.voice where id = new.threadid;
    return new;
end;
$updateThreadsVotes$ LANGUAGE plpgsql;

CREATE TRIGGER insertThreadsVotesTrigger
    AFTER INSERT
    on vote
    for each row
EXECUTE Function insertThreadsVotes();

CREATE TRIGGER updateThreadsVotesTrigger
    AFTER UPDATE
    on vote
    for each row
EXECUTE Function updateThreadsVotes();

CREATE TRIGGER insertPathTreeTrigger
    BEFORE INSERT
    on Post
    for each row
EXECUTE Function insertPathTree();

VACUUM ANALYZE;



