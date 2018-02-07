require 'pp'

module Tiles
  Air = 0
  Grass = 1
  Earth = 2
  Stone = 3
end
def min(a, b)
  return a < b ? a : b
end
def max(a, b)
  return a > b ? a : b
end
class RNG
  attr :seed, :m, :a, :c

  def initialize(seed)
    @seed = seed
    @m = 2**31
    @a = 1103515245
    @c = 12345
  end
  def Random(max)
    @seed = (@a * @seed + @c) % @m;
    return @seed % max
  end
  def GenerateKeyPoint(amp)
    @seed = (@a * @seed + @c) % @m;
    return (@seed % amp) - (amp / 2)
  end
end
class Layer
  attr_accessor :octaves, :base_lvl, :material, :oct_nbr, :amplitude, :wave_length_pow
  def initialize(material, base_lvl, oct_nbr, amplitude, wave_length_pow)
    if oct_nbr > wave_length_pow
      puts "warning : oct_nbr > wave_length_pow"
    end
    @base_lvl, @material, @oct_nbr, @amplitude, @wave_length_pow = base_lvl, material, oct_nbr, amplitude, wave_length_pow
  end

  def generateNew(width_points)
    wl = 2 ** wave_length_pow
    tmp_wp = width_points

    @octaves = Array.new(oct_nbr){Array.new(tmp_wp)}
    for y in 0..oct_nbr - 1
      for x in 0..tmp_wp - 1
        octaves[y][x] = $rng.GenerateKeyPoint(amplitude / (1.5 ** y))

      end
      tmp_wp *= 2
    end
  end
  def generateOctaves(template, copy_n)
    if copy_n > @oct_nbr
      puts "copy_n too big"
      copy_n = oct_nbr
    end
    @octaves = Array.new(template.size)
    if copy_n > 0
      for i in 0..copy_n-1
        @octaves[i] = template[i]
      end
    end
    if oct_nbr > copy_n
      for j in copy_n..oct_nbr-1
        @octaves[j] = Array.new(template[j].size)
        for i in 0..template[j].size - 1
          @octaves[j][i] = $rng.GenerateKeyPoint(amplitude / (1.5**j))
        end
      end
    end
  end

end


class Map

  attr_reader :data, :images

  def initialize()
    @images = Array.new(4)
    @images[0] = 0 # air
    @images[1] = Gosu::Image.new("res/tiles/grass.png")
    @images[2] = Gosu::Image.new("res/tiles/dirt.png")
    @images[3] = Gosu::Image.new("res/tiles/stone.png")

  end

  def setBlock(x, y, v)
    o = @data[x][y]
    @data[x][y] = v
    addBlockToWaitList(x-1, y)
    addBlockToWaitList(x+1, y)
    addBlockToWaitList(x, y-1)
    addBlockToWaitList(x, y+1)
  end

  def interpolate(a, b, x)
    ft = x * Math::PI
    f = (1 - Math.cos(ft)) * 0.5;
    return a * (1 - f) + b * f;
  end

  def load()
    File.open("terrain.map") do |file|
      @data = Marshal.load(file)
    end
  end

  def generate(width_points, h, sea_lvl, wave_length_pow, nb_oct, amplitude)
    w = (2 ** wave_length_pow)*width_points
    layers = Array.new(3)
    puts 1
    layers[0] = Layer.new(Tiles::Grass, sea_lvl, nb_oct, amplitude, wave_length_pow)
    layers[0].generateNew(width_points)
    layers[1] = Layer.new(Tiles::Earth, sea_lvl+1, nb_oct, amplitude, wave_length_pow)
    layers[1].generateOctaves(layers[0].octaves, nb_oct)
    layers[2] = Layer.new(Tiles::Stone, sea_lvl+5, nb_oct, amplitude, wave_length_pow)
    layers[2].generateOctaves(layers[0].octaves, nb_oct - 4)

    puts 2
    @data = Array.new(w){Array.new(h)}

    for y in 0..@data[0].size-1
      for x in 0..@data.size-1
        s = layers.size - 1
        @data[x][y] = Tiles::Air
        for i in 0..s
          l = layers[i].base_lvl
          for j in (0..layers[i].octaves.size-1)
            twl = w / layers[i].octaves[j].size
            a = max(0, x - 1) / twl
            b = min(a + 1, layers[i].octaves[j].size - 1)

            xab = (max(0, x - 1) % twl) / twl.to_f
            l -= interpolate(layers[i].octaves[j][a], layers[i].octaves[j][b], xab)
          end

          if y >= l
            @data[x][y] = layers[i].material
          end

        end
      end
    end
    puts 3
    pStart = 45
    birth = 4
    death = 4
    steps = 3

    caves = Array.new(@data.size){ |j|
      Array.new(data[0].size){ |i|
        $rng.Random(100) < pStart ? true : false
      }
    }

    for j in 0..@data.size - 1
      for i in 0..@data[0].size - 1
        if !caves[i][j]
          @data[i][j] = Tiles::Air
        end
      end
    end

    File.open("terrain.map", "w+") do |file|
      Marshal.dump(@data, file)
    end
    puts 4
end

def draw(posX, posY)
  debutX = (posX / 60) - 32
  debutY = (posY / 60) - 16
  for j in debutY..debutY+32 # Parcous du tableau bidimensionnel
    for i in debutX..debutX+64
      if i >= 0 && j >= 0 && @data[i][j] != Tiles::Air # S'il ne s'agit pas d'un block d'air
        @images[@data[i][j]].draw(2*i*(@images[@data[i][j]].width - 2), 2*j*(@images[@data[i][j]].height - 2), -1, 2, 2) # on le dessine en fonction de sa position dans le tableau
      end
    end
  end
end

  def update(i, j, state)
    @data[i][j] = state
  end

  def solid(x, y)
    #Test pour le bloc du bas gauche/droite et haut gauche/droite s'il est solide
    if @data[x / (30*2)][y / (30*2)] != 0 || @data[((x+58) / (30*2))][y / (30*2)] != 0 || @data[x / (30*2)][(y-64) / (30*2)] !=0 || @data[((x+58) / (30*2))][(y-64) / (30*2)] != 0
      return true
    else
      return false
    end
  end
end
