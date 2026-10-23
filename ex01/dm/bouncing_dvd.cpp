#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <cmath>
#include <numeric>

using namespace std;

int main()
{
    // uncomment the two following lines if you want to read/write from files
    // ifstream cin("input.txt");
    // ofstream cout("output.txt");

    int W, H;
    size_t T;
    cin >> W >> H >> T;

    int x, y, vx, vy;
    cin >> x >> y >> vx >> vy;

    int velGCD = gcd(vx, vy); // TODO: if one of them is 0!
    // cout << "gcd of " << vx << " and " << vy << " is " << gcd(vx, vy) << endl;
    vx /= velGCD;
    vy /= velGCD;
    T *= static_cast<size_t>(velGCD);

    vx %= 2 * W;
    vy %= 2 * H;
    if (vx < 0)
    {
        vx += 2 * W;
    }
    if (vy < 0)
    {
        vy += 2 * H;
    }

    // cout << "vx: " << vx << endl;
    // cout << "vy: " << vy << endl;

    int posX, posY;
    cin >> posX >> posY;

    int temp = x;
    vector<int> xHits, yHits;
    int loopDurationX, loopDurationY;
    for (int i = 0; i <= 2 * W; ++i)
    {
        if (temp == posX || temp == 2 * W - posX)
        {
            xHits.push_back(i);
        }
        temp = (temp + vx) % (2 * W);
        if (temp == x)
        {
            loopDurationX = i + 1;
            break;
        }
    }
    temp = y;
    for (int i = 0; i <= 2 * H; ++i)
    {
        if (temp == posY || temp == 2 * H - posY)
        {
            yHits.push_back(i);
        }
        temp = (temp + vy) % (2 * H);
        if (temp == y)
        {
            loopDurationY = i + 1;
            break;
        }
    }
    // cout << "hits: " << xHits.size() << " " << yHits.size() << endl;
    // cout << "durations: " << loopDurationX << " " << loopDurationY << endl;

    if (xHits.size() == 0 || yHits.size() == 0)
    {
        cout << 0 << endl;
        return EXIT_SUCCESS;
    }

    size_t loopDuration = static_cast<size_t>(loopDurationX) * static_cast<size_t>(loopDurationY) / static_cast<size_t>(gcd(loopDurationX, loopDurationY));

    vector<size_t> hits;
    // TODO: use smaller loopDuration istead of always X
    if (loopDurationX < loopDurationY)
    {
        for (auto yHit : yHits)
        {
            for (size_t i = static_cast<size_t>(yHit); i < loopDuration; i += static_cast<size_t>(loopDurationY))
            {
                for (auto xHit : xHits)
                {
                    if (i % static_cast<size_t>(loopDurationX) == static_cast<size_t>(xHit))
                    {
                        hits.push_back(i);
                    }
                }
            }
        }
    }
    else
    {
        for (auto xHit : xHits)
        {
            for (size_t i = static_cast<size_t>(xHit); i < loopDuration; i += static_cast<size_t>(loopDurationX))
            {
                for (auto yHit : yHits)
                {
                    if (i % static_cast<size_t>(loopDurationY) == static_cast<size_t>(yHit))
                    {
                        hits.push_back(i);
                    }
                }
            }
        }
    }

    size_t bounces = (T / loopDuration) * hits.size();
    size_t rest = T % loopDuration;

    for (auto hit : hits)
    {
        if (hit < rest)
        {
            bounces++;
        }
    }

    cout << bounces << endl;

    return EXIT_SUCCESS;
}
