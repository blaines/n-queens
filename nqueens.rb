# This class handles the game piece positioning
class GameBoard
    def initialize(rows, column_size = rows[0].size)
        @rows = rows
        @column_size = column_size
        @queens = []
    end
    attr_reader :column_size, :rows, :queens
    # Builds the inital game board context (accepts a block)
    def self.build(row_size, column_size = row_size)
        raise ArgumentError if row_size < 0 || column_size < 0
        return to_enum :build, row_size, column_size unless block_given?
        rows = Array.new(row_size) do |i|
            Array.new(column_size) do |j|
                yield i, j
            end
        end
        new rows, column_size
    end
    # A base set of reader and writer methods
    # Can plass a block to mutate the context
    def column(j)
        if block_given?
            row_size.times do |i|
                @rows[i][j] = yield @rows[i][j]
            end
            self
        else
            col = Array.new(row_size) do |i|
                @rows[i][j]
            end
        end
    end
    def row(v)
        @rows[v]
    end
    def row_size
        @rows.size
    end
    def [](r, c)
        @rows.fetch(r){return nil}[c]
    end
    alias element []
    def at(r,c)
        element(r,c)
    end
    def set_at(r,c,v)
        set_element(r,c,v)
    end
    def []=(r,c,v)
        @rows[r][c] = v
    end
    alias set_element []=
    def to_a
        @rows.collect(&:dup)
    end
    # Duplicates the gameboard (for masking context)
    def dup
        GameBoard.build(row_size,column_size) {|r,c| self[r,c]}
    end
    # Calculates the cost of moving to each space (lifts the piece /from/)
    def valid_move_mask(from=nil)
        mask = self.dup
        if from
            queen = mask.element(*from)
            mask.set_at(*from,1)
        end
        mask.rows.flatten.each_index do |i|
            rc = i.divmod(mask.column_size)
            if mask.element(*rc).class==Queen
                mask.row(rc[0]).map! {|e| e=(e.class == Queen ? e : e+=1)}
                mask.column(rc[1]) {|e| e=(e.class == Queen ? e : e+=1)}
                mask.rows.each_with_index do |row,index|
                    mx,my = rc[0]+index,rc[1]-index
                    px,py = rc[0]+index,rc[1]+index
                    valid_range = 0...column_size
                    if valid_range.include?(mx) && valid_range.include?(my)
                        row[my]=(row[my].class == Queen ? row[my] : row[my]+=1)
                    end
                    if valid_range.include?(px) && valid_range.include?(py)
                        row[py]=(row[py].class == Queen ? row[py] : row[py]+=1)
                    end
                end
            end
        end
        mask.set_at(*from,queen) if from
        mask
    end
    # Given a move mask, which space has the lowest cost?
    def best_available_position(queen)
        mask = valid_move_mask(queen)
        avail = mask.column(queen[1])
        row = avail.rindex(avail.min_by {|x| x.to_i})
        [row,queen[1]]
    end
    def new_queen(rc)
        throw "Argument must be an Array" unless rc.class == Array
        queen = Queen.new(self,rc)
        @queens.push(queen)
        set_element(*rc,queen)
    end
    # Inspection methods
    def inspect
        inspection = rows.map {|r| r.map {|c| c=(c.class==Queen ? '*' : c)}} 
        inspection.map! {|r| r.join(" ")}
        inspection.unshift("GameBoard")
        inspection.join("\n    ")
    end
    def pretty
        inspection = rows.map {|r| r.map {|c| c=(c.class==Queen ? '*' : '-')}} 
        inspection.map! {|r| r.join(" ")}
        inspection.unshift("GameBoard")
        inspection.join("\n    ")
    end
end

# This is our only game piece
class Queen
    def initialize(game_board,rc)
        @game_board = game_board
        @rc = rc
        @move_count=0
    end
    # boilerplate
    attr_reader :move_count
    def reset_move_count
        @move_count=0
    end
    def position
        @rc
    end
    # Similar to the move mask, but calculate the number of collisions for this game piece
    def collisions
        from = @rc
        mask = @game_board.dup
        if from
            queen = mask.element(*from)
            mask.set_at(*from,1)
        end
        rc = from
        collision_count = 0
        collision_count += mask.row(rc[0]).count {|e| e.class == Queen}
        collision_count += mask.column(rc[1]).count {|e| e.class == Queen}

        mask.rows.each_with_index do |row,index|
            p_row = @rc[0]+index
            m_row = @rc[0]-index
            p_col = @rc[1]+index
            m_col = @rc[1]-index
            a,b,c,d = [m_row,m_col],[m_row,p_col],[p_row,m_col],[p_row,p_col]
            valid_range = 0...mask.column_size
            collision_count+=1 if valid_range.include?(m_row) && valid_range.include?(m_col) && mask[*a].class == Queen
            collision_count+=1 if valid_range.include?(m_row) && valid_range.include?(p_col) && mask[*b].class == Queen
            collision_count+=1 if valid_range.include?(p_row) && valid_range.include?(m_col) && mask[*c].class == Queen
            collision_count+=1 if valid_range.include?(p_row) && valid_range.include?(p_col) && mask[*d].class == Queen
        end
        mask.set_at(*from,queen) if from
        collision_count
    end
    # Move this piece to a new position, and remove it from the old position
    def move_to(r,c)
        @move_count += 1
        mv = @game_board[r,c]
        @game_board[r,c]=@game_board.element(*@rc)
        @game_board.set_element(*@rc,mv+1)
        @rc=[r,c]
    end
    # Inspection methods (probably bad but I like)
    def inspect
        "Queen:[#{@rc.join(',')}]!#{collisions}"
    end
    # Cheap hack for finding min move danger
    def to_i
        9999
    end
    def to_s
        "Queen"
    end
end

# Runme!
# If too many pointless iterations occur, shuffle!
def run(n)
    return "Really? Run me with a real number greater than 3!" if n<4
    @board = GameBoard.build(n,n) {|i| i = 0}
    @board.row(0).each_index {|c| @board.new_queen([0,c])}
    @last_move=nil
    z = 0
    witty_remarks = ["Working...","Busy...","Reticulating splines...","Counting vector articulation...","Pleasing the masses...","Getting a coffee...","Finding a safe place...","Moving...","There's #{n} queens in the room, it's gonna be a while...","Being greedy..."]
    while true
        max_collisions = @board.queens.max_by {|x| x.collisions}.collisions
        problem_queens = @board.queens.select {|x| x.collisions == max_collisions}.shuffle
        if problem_queens.size > 1
            queen = problem_queens.select {|x| x.position[1]!=@last_move}.last
        else
            queen = problem_queens.first
        end
        if queen.move_count > (n*100)/10
            # print "~"
            @board.queens.each do |e|
                r = Random.rand(n)
                until r!=e.position[0]
                    r = Random.rand(n)
                end
                e.move_to(r,e.position[1])
                e.reset_move_count
            end
            next
        end
        # print "*"
        puts witty_remarks.shuffle.first if z%200==0 && z>0
        if queen.collisions == 0
            print "\n"
            puts "WIN!"
            puts @board.valid_move_mask.pretty
            break
        end
        move = @board.best_available_position(queen.position)
        @last_move=move[1]
        @board[*queen.position].move_to(*move)
        z+=1
    end

    @board
end
run ARGV[0].to_i