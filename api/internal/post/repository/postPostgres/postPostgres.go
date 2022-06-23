package postPostgres

import (
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mailcourses/technopark-dbms-forum/api/internal/domain"
	"golang.org/x/net/context"
	"strings"
)

type PostRepo struct {
	pool *pgxpool.Pool
}

func NewPostRepo(pool *pgxpool.Pool) domain.PostRepo {
	return PostRepo{pool: pool}
}

func (repo PostRepo) SelectById(id int64, params domain.PostParams) (*domain.PostFull, error) {
	postFull := domain.PostFull{}
	query := `SELECT id, parent, author, message, is_edited, forum, thread, created
			  FROM Post
			  WHERE id = $1;`
	post := domain.Post{}
	if err := repo.pool.QueryRow(context.Background(), query, id).Scan(domain.GetPostFields(&post)...); err != nil {
		return nil, err
	}
	postFull.Post = &post

	if params.Forum {
		forum := domain.Forum{}
		getForumQuery := `SELECT title, f.user_nickname, slug, posts, threads
						  FROM Forum f
					      WHERE slug = $1;`
		if err := repo.pool.QueryRow(context.Background(), getForumQuery, postFull.Post.Forum).Scan(domain.GetForumFields(&forum)...); err != nil {
			return nil, err
		}
		postFull.Forum = &forum
	}

	if params.Thread {
		thread := domain.Thread{}
		getThreadQuery := `SELECT t.id, title, t.user_nickname, t.forum, t.message, votes, slug, t.created
						  FROM Thread t
						  WHERE t.id = $1;`
		if err := repo.pool.QueryRow(context.Background(), getThreadQuery, postFull.Post.Thread).Scan(domain.GetThreadFields(&thread)...); err != nil {
			return nil, err
		}
		postFull.Thread = &thread
	}

	if params.User {
		user := domain.User{}
		getUserQuery := `SELECT nickname, fullname, about, email
						  FROM Users u
						  WHERE nickname = $1;`
		if err := repo.pool.QueryRow(context.Background(), getUserQuery, postFull.Post.Author).Scan(domain.GetUserFields(&user)...); err != nil {
			return nil, err
		}
		postFull.Author = &user
	}

	return &postFull, nil
}

func (repo PostRepo) UpdateMsg(id int64, postUpdate domain.PostUpdate, isEdited bool) (*domain.Post, error) {
	query := `UPDATE Post
			 SET message = $2, is_edited = $3
			 WHERE id = $1
			 RETURNING id, parent, author, message, is_edited, forum, thread, created;`

	updated := domain.Post{}
	if err := repo.pool.QueryRow(context.Background(), query, id, postUpdate.Message, isEdited).Scan(domain.GetPostFields(&updated)...); err != nil {
		return nil, err
	}

	return &updated, nil
}

func (repo PostRepo) CreatePosts(posts []domain.Post, forum string, threadId int32) ([]domain.Post, error) {
	elements := len(posts)

	query := `INSERT INTO Post (parent, author, message, is_edited, forum, thread, created)
			  VALUES `

	const postFields = 7
	query, args, err := prepareQueryWithArgs(posts, query, postFields, threadId, forum, repo.pool)
	if err != nil {
		return nil, err
	}

	rows, err := repo.pool.Query(context.Background(), query, args...)

	if err != nil {
		return nil, err
	}

	result := make([]domain.Post, elements)

	insertToForumUsersQuery := `INSERT INTO ForumUsers (nickname, fullname, about, email, forum) values`
	paramNumber := 1
	forumUsersFields := 5
	var forumUsersParams []interface{}
	for i := 0; rows.Next(); i++ {
		err = rows.Scan(domain.GetPostFields(&result[i])...)

		if err != nil {
			return nil, err
		}

		currUser := domain.User{}
		getUserQuery := `SELECT nickname, fullname, about, email from users where nickname = $1;`
		if err := repo.pool.QueryRow(context.Background(), getUserQuery, strings.ToLower(result[i].Author)).Scan(domain.GetUserFields(&currUser)...); err != nil {
			return nil, err
		}

		if i > 0 {
			insertToForumUsersQuery += ","
		}

		insertToForumUsersQuery += fmt.Sprintf(" ($%d, $%d, $%d, $%d, $%d)", paramNumber, paramNumber+1, paramNumber+2, paramNumber+3, paramNumber+4)
		forumUsersParams = append(forumUsersParams, currUser.Nickname, currUser.Fullname, currUser.About, currUser.Email, forum)
		paramNumber += forumUsersFields
	}

	insertToForumUsersQuery += " ON CONFLICT DO NOTHING;"

	if len(result) > 0 {
		forumToIncPosts := result[0].Forum
		updForumPostsThreads := `UPDATE forum set posts = posts + $1 where forum.slug = $2;`
		if _, err := repo.pool.Exec(context.Background(), updForumPostsThreads, elements, strings.ToLower(forumToIncPosts)); err != nil {
			return nil, err
		}

		if _, err := repo.pool.Exec(context.Background(), insertToForumUsersQuery, forumUsersParams...); err != nil {
			return nil, err
		}
	}

	return result, nil
}
